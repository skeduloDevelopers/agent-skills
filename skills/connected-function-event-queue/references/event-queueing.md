# Event Queueing Reference

The Skedulo platform delivers triggered action payloads synchronously — if your function takes too long or the platform batches many records in one shot, you risk timeouts and dropped work. The event queue lets you hand work off asynchronously: the manifest posts records to a queue receiver instead of directly to your function, and a separate worker delivers them to your handler in controlled-size batches.

## How Event Queueing Works — End to End

```text
Skedulo record changes
        │
        ▼
Triggered Action Manifest — action.url points to event-queue-receiver/enqueue
        │  (sked-function-handler-url header tells the queue where to forward)
        ▼
event-queue-receiver buffers the payload
        │  (respects sked-event-queue-priority)
        ▼
Worker delivers payload to your function handler
        │  (same TriggerActionPayloadItem<T>[] body your handler already expects)
        ▼
Your handler processes the batch — optionally re-chunks and re-enqueues
```

There are two independent places where chunking can happen:

1. **Manifest level** — the platform sends all changed records in one POST to the queue receiver. The queue receiver holds them until a worker delivers them.
2. **Handler level** — if the worker delivers more records than your handler can safely process inline, you chunk and re-enqueue using the `enqueue()` helper.

In practice, most handlers use both.

---

## Part 1: Manifest — Route to the Queue Receiver

Instead of pointing `action.url` at your function directly, point it at the event queue receiver and use headers to specify where the payload should ultimately go.

### Standard event-queue manifest

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "job-after-inserted",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'INSERT'"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/event-queue-receiver/event-queue-receiver/enqueue",
    "headers": {
      "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}",
      "sked-function-handler-url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-insert",
      "sked-function-execution-type": "async",
      "sked-event-queue-priority": "1"
    },
    "query": "{ UID Name JobStatus AccountId RegionId Start End }"
  }
}
```

### Key differences from a direct-call manifest

| Field | Direct call | Event queue |
| --- | --- | --- |
| `action.url` | Your function endpoint | `{{SKEDULO_API_URL}}/function/event-queue-receiver/event-queue-receiver/enqueue` |
| `sked-function-handler-url` | Not present | Your function endpoint (the queue forwards here) |
| `sked-event-queue-priority` | Not present | Integer 1–100; lower = processed first |
| `sked-function-execution-type` | `"async"` recommended | `"async"` — always set this |

### `sked-event-queue-priority` — priority guide

Lower numbers are processed first. Use priority to enforce ordering when multiple triggered actions compete for the same worker:

| Priority range | Typical use |
| --- | --- |
| 1–5 | INSERT operations, time-sensitive work (job/allocation creation) |
| 10–15 | Derived-field population (travel time, postal codes) |
| 20–30 | Validation and rule evaluation |
| 50+ | Low-urgency background work, migrations |

When multiple queued items share the same priority they are processed in FIFO order.

---

## Part 2: The `EventQueue` Type and `enqueue()` Helper

Your function re-enqueues work programmatically when a batch arrives that is too large to process inline.

### Types

```typescript
// EventQueue — one unit of queued work
export interface EventQueue {
  Payload: any                // The body your handler will receive
  FunctionHandlerUrl: string  // Full URL of the handler that will process it
  Priority?: number           // 1–100, lower = processed first (default: 50)
}
```

`Payload` must be shaped as `TriggerActionPayloadItem<T>[]` so the receiving handler can parse it with `createTriggeredActionHandler` without any special casing:

```typescript
// Shape that createTriggeredActionHandler expects
type TriggerActionPayloadItem<T> = {
  data: { [objectNameCamelCase: string]: T }
  previous: T | null
  operation: 'INSERT' | 'UPDATE' | 'DELETE'
}
```

### `enqueue()` helper

```typescript
// src/utils/enqueue.ts
import { getExecutionContext } from '@skedulo/pulse-solutions-framework'
import { EventQueue } from '../models'

const ENQUEUE_ENDPOINT = 'function/event-queue-receiver/event-queue-receiver/enqueue-bulk'

export const enqueue = async (eventQueues: EventQueue[]): Promise<void> => {
  await getExecutionContext().baseClient.performRequest({
    method: 'post',
    endpoint: ENQUEUE_ENDPOINT,
    body: eventQueues
  })
}
```

`enqueue-bulk` accepts an array — pass all chunks in a single call rather than looping with individual calls.

---

## Part 3: Handler-Level Chunking Pattern

When a batch exceeds your safe processing limit, chunk records and enqueue them instead of processing inline. Return HTTP 202 so the caller knows the work was accepted but not yet completed.

### Constants

```typescript
// src/utils/constants.ts
const MAX_RECORDS_PER_QUEUE = 5  // tune per object complexity and downstream latency
```

Keep this small enough that a single handler invocation completes within the platform's timeout. 5 is a safe default for objects with multiple downstream mutations; simpler operations can go higher.

### INSERT handler with chunking

```typescript
// src/handlers/job-handler.ts
import { chunk } from 'lodash'
import { enqueue } from '../utils/enqueue'
import { EventQueue, Jobs } from '../models'

const MAX_JOBS_PER_QUEUE = 5

export const afterInsertJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: triggerContext }) => {
    const { newRecords } = triggerContext

    if (newRecords.length > MAX_JOBS_PER_QUEUE) {
      const eventQueues: EventQueue[] = chunk(newRecords, MAX_JOBS_PER_QUEUE).map(jobChunk => ({
        Payload: jobChunk.map(job => ({
          data: { jobs: job },
          previous: null,
          operation: 'INSERT'
        })),
        FunctionHandlerUrl: `${ConfigurationVariables.SKEDULO_API_URL}/function/my-function/my-function/triggered-action/job-after-insert`,
        Priority: 1
      }))

      await enqueue(eventQueues)
      return { status: 202, body: { message: `${newRecords.length} jobs queued for processing` } }
    }

    // Process inline when under threshold
    await createJobTimeConstraints(newRecords)
    await populatePostalCodes(newRecords)
    return { status: 200, body: { processed: newRecords.length } }
  }
)
```

### UPDATE handler with chunking — preserve `previous`

For UPDATE operations, `previous` must be included in each queued payload item so the receiving handler can diff old vs new:

```typescript
export const afterUpdateJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: triggerContext }) => {
    const { newRecords, mapOldRecord } = triggerContext

    if (newRecords.length > MAX_JOBS_PER_QUEUE) {
      const eventQueues: EventQueue[] = chunk(newRecords, MAX_JOBS_PER_QUEUE).map(jobChunk => ({
        Payload: jobChunk.map(job => ({
          data: { jobs: job },
          previous: mapOldRecord[job.UID] ?? null,  // ← carry old record through
          operation: 'UPDATE'
        })),
        FunctionHandlerUrl: `${ConfigurationVariables.SKEDULO_API_URL}/function/my-function/my-function/triggered-action/job-after-update`,
        Priority: 5
      }))

      await enqueue(eventQueues)
      return { status: 202, body: { message: `${newRecords.length} jobs queued for processing` } }
    }

    await processJobUpdates(newRecords, mapOldRecord)
    return { status: 200, body: { processed: newRecords.length } }
  }
)
```

### Mid-handler enqueue — offload expensive work

You can also enqueue from inside a sub-operation when processing a record triggers expensive downstream work. The handler does lightweight work inline and delegates the expensive part:

```typescript
const enqueueJobRuleEvaluation = async (jobs: Jobs[]) => {
  const MAX_PER_QUEUE = 10

  const eventQueues: EventQueue[] = chunk(jobs, MAX_PER_QUEUE).map(jobChunk => ({
    Payload: jobChunk.map(job => ({
      data: { jobs: job },
      previous: null,
      operation: 'UPDATE'
    })),
    FunctionHandlerUrl: `${ConfigurationVariables.SKEDULO_API_URL}/function/my-function/my-function/triggered-action/job-evaluate-rules`,
    Priority: 20
  }))

  if (eventQueues.length > 0) {
    await enqueue(eventQueues)
  }
}
```

Guard the enqueue call with `if (eventQueues.length > 0)` — `enqueue([])` is a no-op but wastes a network round-trip.

---

## Part 4: Configurable Thresholds via `ConfigurationVariables`

Hard-coded chunk sizes become a problem when object complexity varies by tenant. Expose the threshold as a config var so it can be tuned without a code deploy:

**`sked.proj.json`:**

```json
{
  "settings": {
    "configVars": [
      {
        "name": "MAX_JOB_ALLOCATIONS_PER_QUEUE",
        "configType": "plain-text",
        "description": "Max job allocations processed per event queue item. Lower if downstream calls are slow.",
        "default": "5"
      }
    ]
  }
}
```

**`src/utils/configuration-variables.ts`:**

```typescript
export class ConfigurationVariables {
  static MAX_JOB_ALLOCATIONS_PER_QUEUE: number = 5

  static init(skedContext: SkedContext): void {
    const raw = skedContext?.configVars?.getVariableValue('MAX_JOB_ALLOCATIONS_PER_QUEUE')
    ConfigurationVariables.MAX_JOB_ALLOCATIONS_PER_QUEUE = raw ? parseInt(raw, 10) : 5
  }
}
```

---

## Part 5: HTTP Status Semantics

| Status | Meaning | When to return |
| --- | --- | --- |
| `200` | Processed inline | Records were under threshold and fully handled |
| `202` | Accepted, queued | Records exceeded threshold and were enqueued |
| `207` | Multi-Status | Some inline sub-handlers failed (ChangeHandler pattern) |
| `500` | Error | Unhandled exception — do not enqueue on error |

The queue receiver treats any non-2xx response from the initial manifest call as a delivery failure and may retry. Your handler returning 202 does **not** trigger a retry — the work is now the queue's responsibility.

---

## Part 6: Route Registration for Queue-Forwarded Handlers

Queue-forwarded handlers are registered identically to direct handlers. There is no special registration needed:

```typescript
// src/routes/job.ts
export function getJobRoutes(): FunctionRoute[] {
  return [
    { method: 'post', path: '/triggered-action/job-after-insert', handler: afterInsertJobHandler },
    { method: 'post', path: '/triggered-action/job-after-update', handler: afterUpdateJobHandler },
    // Dedicated handler for expensive sub-operation, also called via event queue
    { method: 'post', path: '/triggered-action/job-evaluate-rules', handler: jobEvaluateRulesHandler },
  ]
}
```

The `sked-function-handler-url` in the manifest and the `FunctionHandlerUrl` in enqueued `EventQueue` objects must both resolve to paths registered here.

---

## Checklist

Before deploying a triggered action that uses event queueing:

- [ ] Manifest `action.url` points to `event-queue-receiver/event-queue-receiver/enqueue`, not your function directly
- [ ] `sked-function-handler-url` header is set to your actual function endpoint
- [ ] `sked-event-queue-priority` is set and reflects processing urgency relative to other actions
- [ ] Handler checks `newRecords.length > MAX_RECORDS_PER_QUEUE` before deciding inline vs enqueue
- [ ] UPDATE handlers carry `previous: mapOldRecord[record.UID]` through into the enqueued payload
- [ ] `enqueue()` is called with all chunks in a single call (not looped individually)
- [ ] `enqueue([])` is guarded against (check `eventQueues.length > 0` before calling)
- [ ] Handler returns `202` when enqueuing, `200` when processing inline
- [ ] Chunk size is tuned for the slowest downstream operation in the handler
- [ ] Handler is idempotent — the queue may redeliver on transient failures
