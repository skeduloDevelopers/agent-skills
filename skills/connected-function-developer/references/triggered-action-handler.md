# Triggered Action Handler Reference

Triggered actions fire automatically when Skedulo records are created, updated, or deleted. The platform sends an HTTP POST to your function endpoint with the changed record data.

## How Triggered Actions Work — End to End

```text
Skedulo record changes
        │
        ▼
Triggered Action Manifest evaluates trigger.filter
        │  (Operation == 'UPDATE' AND Current.Status != Previous.Status)
        ▼
Platform fetches fields listed in action.query / action.previousFields
        │
        ▼
HTTP POST to your function endpoint
        │  (body = TriggerActionPayloadItem<T>[])
        ▼
Your handler processes newRecords / mapOldRecord
```

---

## Part 1: The Manifest File

Every triggered action requires a JSON manifest file deployed to `src/triggered-actions/`. This tells the Skedulo platform **when** to fire, **what data** to include, and **where** to send it.

### Basic manifest structure

```json
{
  "metadata": {
    "type": "TriggeredAction"
  },
  "name": "job-after-updated",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'UPDATE'"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-update",
    "headers": {
      "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}",
      "sked-function-execution-type": "async"
    },
    "query": "{ UID Name JobStatus AccountId RegionId Start End }",
    "previousFields": "{ UID Name JobStatus AccountId RegionId Start End }"
  }
}
```

### Key manifest fields

| Field | Required | Description |
| --- | --- | --- |
| `trigger.schemaName` | Yes | Skedulo object to watch (`Jobs`, `Accounts`, `Resources`, etc.) |
| `trigger.filter` | Yes | EQL condition controlling when this fires |
| `action.url` | Yes | Your function endpoint. Use `{{SKEDULO_API_URL}}` placeholder |
| `action.query` | Yes | GraphQL-style field list for the **new/current** record sent to your function |
| `action.previousFields` | UPDATE/DELETE only | Field list for the **old** record. **Omit entirely for INSERT-only handlers** — `previous` is `null` for INSERT and the platform has no previous state to send |
| `headers.sked-function-execution-type` | Recommended | `"async"` to avoid platform timeouts on slow operations |

### INSERT vs UPDATE manifest — `previousFields` difference

**INSERT** — no `previousFields`, `previous` is always `null`:

```json
{
  "name": "job-after-inserted",
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'INSERT'"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-insert",
    "headers": { "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}", "sked-function-execution-type": "async" },
    "query": "{ UID Name JobStatus RegionId }"
  }
}
```

**UPDATE** — `previousFields` required to access old values:

```json
{
  "name": "job-after-updated",
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'UPDATE' AND (Current.JobStatus != Previous.JobStatus)"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-update",
    "headers": { "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}", "sked-function-execution-type": "async" },
    "query": "{ UID Name JobStatus RegionId }",
    "previousFields": "{ UID JobStatus }"
  }
}
```

### `trigger.filter` — when to fire

Use EQL expressions to narrow when the action fires:

```text
Operation == 'INSERT'
Operation == 'UPDATE'
Operation == 'DELETE'

# Fire only on specific field changes:
Operation == 'UPDATE' AND (Current.JobStatus != Previous.JobStatus OR Current.RegionId != Previous.RegionId)

# Combine with field conditions:
Operation == 'UPDATE' AND Current.JobStatus == 'Complete'
```

### `action.query` — what fields your function receives

**Critical:** Your handler only receives the fields listed in `query`. If a field is not listed, it will be `undefined` in your handler.

```json
"query": "{ UID Name JobStatus AccountId RegionId Start End Duration Address PostalCode }"
```

### `action.previousFields` — old record fields for UPDATE/DELETE

Similarly, only fields listed here are available in `mapOldRecord`. For INSERT-only handlers, omit this field.

```json
"previousFields": "{ UID Name JobStatus AccountId RegionId Address }"
```

### Manifest with narrow UPDATE filter

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "job-status-changed",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'UPDATE' AND (Current.JobStatus != Previous.JobStatus)"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-update",
    "headers": {
      "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}",
      "sked-function-execution-type": "async"
    },
    "query": "{ UID Name JobStatus AccountId }",
    "previousFields": "{ UID JobStatus }"
  }
}
```

### Upsert pattern — one handler for INSERT and UPDATE

When INSERT and UPDATE logic is nearly identical (e.g. populating a derived field whenever a record is created or changed), point two separate manifests at the same handler endpoint instead of duplicating code.

**Manifest 1 — INSERT:**

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "account-after-inserted",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Accounts",
    "filter": "Operation == 'INSERT'"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/account-after-upsert",
    "headers": { "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}", "sked-function-execution-type": "async" },
    "query": "{ UID Name BillingStreet BillingCity BillingState BillingPostalCode RegionId }"
  }
}
```

**Manifest 2 — UPDATE:**

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "account-after-updated",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Accounts",
    "filter": "Operation == 'UPDATE' AND (Current.BillingStreet != Previous.BillingStreet OR Current.BillingCity != Previous.BillingCity)"
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/account-after-upsert",
    "headers": { "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}", "sked-function-execution-type": "async" },
    "query": "{ UID Name BillingStreet BillingCity BillingState BillingPostalCode RegionId }",
    "previousFields": "{ UID BillingStreet BillingCity }"
  }
}
```

**One shared handler** — registered under a single route `/triggered-action/account-after-upsert`. The handler uses `isInsert` / `isUpdate` flags if it needs to branch:

```typescript
export const afterUpsertAccountHandler = createTriggeredActionHandler<Accounts>(
  'Accounts',
  async ({ data: triggerContext }) => {
    await populateDisplayAddress(triggerContext.newRecords)
    if (triggerContext.isUpdate) {
      await populateRegionFromPostalCode(triggerContext.newRecords)
    }
    return { status: 200, body: { processed: triggerContext.newRecords.length } }
  }
)
```

Route registration stays the same — one `POST /triggered-action/account-after-upsert` entry.

**When to use this pattern vs separate handlers:**

| Use upsert pattern | Use separate handlers |
| --- | --- |
| INSERT and UPDATE share the same derived-field logic | Different fields queried per operation |
| UPDATE filter is narrow enough that INSERT logic is also safe to run | Significantly different business logic per operation |
| Reduces duplicated handler code | Need independent feature flags per operation |

### Deferred triggers — time-based execution

A triggered action can fire at a calculated time relative to a field value instead of immediately when the record changes. Use `trigger.deferred` for reminders, scheduled checks, or actions that need to run *before* or *after* a point in time.

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "notify-before-job-start",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Operation == 'UPDATE' AND Current.JobStatus == 'Queued'",
    "deferred": {
      "fieldName": "Start",
      "offset": -1800000
    }
  },
  "action": {
    "type": "call_url",
    "url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/notify-before-job-start",
    "headers": { "Authorization": "Bearer {{ SKEDULO_USER_TOKEN }}", "sked-function-execution-type": "async" },
    "query": "{ UID Name Start JobStatus ResourceId }"
  }
}
```

**`trigger.deferred` fields:**

| Field | Description |
| --- | --- |
| `fieldName` | The datetime field on the record to anchor the execution time (e.g. `Start`, `End`) |
| `offset` | Millisecond offset from `fieldName`. Negative = before the field value. `0` = exactly at that time |

Common offset values:

```text
-1800000   →  30 minutes before
-3600000   →  1 hour before
 0         →  at the exact field time
 3600000   →  1 hour after
```

**Key considerations:**

- The trigger still evaluates `filter` at record-change time to decide whether to schedule the deferred action. If the filter matches, the action is queued for later.
- If the record changes again before the scheduled time, the platform may re-evaluate and reschedule.
- The handler receives the record state **at execution time**, not at the time the trigger fired.
- Always guard against stale state — the `JobStatus` at execution may differ from what matched the filter.

```typescript
export const notifyBeforeJobStartHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: { newRecords } }) => {
    // Re-check status at execution time — record may have changed since trigger fired
    const stillQueued = newRecords.filter(j => j.JobStatus === 'Queued')
    if (!stillQueued.length) {
      return { status: 200, body: { message: 'Jobs no longer in Queued status, skipping' } }
    }

    await sendNotifications(stillQueued)
    return { status: 200, body: { notified: stillQueued.length } }
  }
)
```

---

## Part 2: Payload Structure

Your function receives a POST body of type `TriggerActionPayloadItem<T>[]`:

```typescript
import { TriggerActionPayloadItem, OPERATION } from '@skedulo/pulse-solutions-framework'

// Each item represents one changed record
interface TriggerActionPayloadItem<T extends BaseModel> {
  operation: OPERATION        // 'INSERT' | 'UPDATE' | 'DELETE'
  data: {
    [objectNameCamelCase: string]: T  // e.g. data.jobs for Jobs, data.accounts for Accounts
  }
  previous: T | null          // ⚠️ null for INSERT — only populated for UPDATE and DELETE
}

enum OPERATION {
  INSERT = 'INSERT',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE'
}
```

The `data` object key is the **camelCase** form of the object name:

- `Jobs` → `data.jobs`
- `Accounts` → `data.accounts`
- `JobAllocations` → `data.jobAllocations`

### `previous` field availability

| Operation | `data` | `previous` |
| --- | --- | --- |
| INSERT | New record | `null` — not available |
| UPDATE | Record after change | Record before change |
| DELETE | Record before deletion | Record before deletion |

This is why `action.previousFields` should be omitted (or set to `null`) in INSERT-only manifests — the platform has no previous state to send. In the handler factory, `mapOldRecord` will be an empty object `{}` for INSERT operations.

---

## Part 3: Handler Factory

Use `createTriggeredActionHandler` to parse the raw payload into a typed `TriggerContext`. Place it in `src/handlers/base-handler.ts`.

### TriggerContext type

```typescript
// src/handlers/types.ts
export interface TriggerContext<T extends BaseModel> {
  objectName: string
  newRecords: T[]                    // Records after change. Empty array for DELETE
  mapOldRecord: Record<string, T>    // Previous state keyed by UID
  isInsert: boolean
  isUpdate: boolean
  isDelete: boolean
}
```

### Factory implementation

```typescript
// src/handlers/triggered-action-handler.ts
import { BaseModel, TriggerActionPayloadItem } from '@skedulo/pulse-solutions-framework'
import { camelCase } from 'lodash'
import { FunctionResponse } from '@skedulo/sdk-utilities'
import { HandlerContext, TriggerContext } from './types'
import { createBaseHandler } from './base-handler'

const OPERATION_INSERT = 'INSERT'
const OPERATION_UPDATE = 'UPDATE'
const OPERATION_DELETE = 'DELETE'

export const createTriggeredActionHandler = <T extends BaseModel>(
  inputObjectName: string,
  func: (handlerContext: HandlerContext<TriggerContext<T>>) => Promise<FunctionResponse<T>>
) => {
  return createBaseHandler<T>(async ({ data: body, headers: customHeaders, params }) => {
    const payload = body as TriggerActionPayloadItem<T>[]
    if (!Array.isArray(payload) || payload.length === 0) {
      return { status: 400, body: { error: 'Empty triggered action payload' } }
    }
    const objectName = camelCase(inputObjectName)
    const { operation } = payload[0]

    const newRecords =
      operation === OPERATION_DELETE ? [] : payload.map(item => item.data[objectName])

    const mapOldRecord = payload.reduce((acc: Record<string, T>, item) => {
      const recordId = item.previous?.UID || item.data[objectName].UID
      acc[recordId] = item.previous
      return acc
    }, {})

    const triggerContext: TriggerContext<T> = {
      objectName: inputObjectName,
      newRecords,
      mapOldRecord,
      isInsert: operation === OPERATION_INSERT,
      isUpdate: operation === OPERATION_UPDATE,
      isDelete: operation === OPERATION_DELETE
    }

    return await func({ data: triggerContext, headers: customHeaders, params })
  })
}
```

---

## Part 4: Handler Examples

### After INSERT — create related records

```typescript
// src/handlers/job-handler.ts
export const afterInsertJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: triggerContext }) => {
    await createJobTimeConstraints(triggerContext.newRecords)

    return {
      status: 200,
      body: { message: `Processed ${triggerContext.newRecords.length} inserted jobs` }
    }
  }
)
```

### After UPDATE — diff old vs new record

Only process records where a relevant field actually changed:

```typescript
export const afterUpdateJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: triggerContext }) => {
    const { newRecords, mapOldRecord } = triggerContext

    const statusChanges = newRecords.filter(job => {
      const oldRecord = mapOldRecord[job.UID]
      return oldRecord && oldRecord.JobStatus !== job.JobStatus
    })

    if (!statusChanges.length) {
      return { status: 200, body: { message: 'No relevant changes, skipping' } }
    }

    await processStatusChanges(statusChanges)

    return {
      status: 200,
      body: { message: `Processed ${statusChanges.length} status changes` }
    }
  }
)
```

### After UPDATE — multiple field conditions

```typescript
export const afterUpdateJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: { newRecords, mapOldRecord } }) => {
    const jobsToProcess = newRecords.filter(job => {
      const old = mapOldRecord[job.UID]
      if (!old) return false
      // React to address changes or start time changes
      return (old.Address !== job.Address && job.Address != null) || old.Start !== job.Start
    })

    if (!jobsToProcess.length) {
      return { status: 200, body: { message: 'No address/time changes, skipping' } }
    }

    await updatePostalCodes(jobsToProcess)
    return { status: 200, body: { processed: jobsToProcess.length } }
  }
)
```

### After DELETE — clean up related data

For DELETE, `newRecords` is empty. Use `mapOldRecord` to access the deleted records:

```typescript
export const afterDeleteJobAllocationHandler = createTriggeredActionHandler<JobAllocations>(
  'JobAllocations',
  async ({ data: { isDelete, mapOldRecord } }) => {
    if (!isDelete) return { status: 200, body: { message: 'Not a delete, skipping' } }

    const deletedAllocations = Object.values(mapOldRecord)
    await reevaluateExceptionRules(deletedAllocations)

    return { status: 200, body: { processed: deletedAllocations.length } }
  }
)
```

---

## Part 5: Scaling the Handler — ChangeHandler Pattern

The basic handler in Part 4 works for simple cases, but as you add more reactions to a single operation it has real problems:

```typescript
// Don't do this for complex handlers
async ({ data: triggerContext }) => {
  await handleStatusChange(triggerContext.newRecords, triggerContext.mapOldRecord)
  await handleAddressChange(triggerContext.newRecords, triggerContext.mapOldRecord)
  await handleRegionChange(triggerContext.newRecords, triggerContext.mapOldRecord)
  return { status: 200, body: { processed: triggerContext.newRecords.length } }
}
```

Problems:

- **No error isolation** — if `handleStatusChange` throws, the others never run
- **No per-reaction observability** — logs only show "handler failed", not which sub-handler or how many records each touched
- **Predicate logic duplicated** — every sub-handler re-implements its own `newRecords.filter(r => oldRecord[r.UID]?.X !== r.X)` boilerplate
- **Hard to disable a single reaction** — requires a code change, no feature-flag path
- **No declarative overview** — you can't scan the code and see "what reactions exist for Jobs UPDATE"

### The pattern

Treat each reaction as a declarative **`ChangeHandler`** object with a predicate (`shouldRun`) and an action (`run`). A dispatcher iterates the list, isolates errors, and reports per-handler results.

### Shared types

```typescript
// src/handlers/types.ts
import { BaseModel } from '@skedulo/pulse-solutions-framework'

export interface ChangeHandler<T extends BaseModel> {
  name: string
  enabled?: boolean | (() => boolean)
  shouldRun: (newRecord: T, oldRecord: T | undefined, ctx: TriggerContext<T>) => boolean
  run: (matchedRecords: T[], ctx: TriggerContext<T>) => Promise<void>
}

export interface ChangeHandlerResult {
  name: string
  status: 'ok' | 'failed' | 'skipped' | 'disabled'
  matched: number
  durationMs: number
  error?: string
}
```

### Shared dispatcher

```typescript
// src/handlers/dispatch-change-handlers.ts
import { BaseModel } from '@skedulo/pulse-solutions-framework'
import { ChangeHandler, ChangeHandlerResult, TriggerContext } from './types'

const isEnabled = (enabled: boolean | (() => boolean) | undefined): boolean => {
  if (enabled === undefined) return true
  if (typeof enabled === 'function') return enabled()
  return enabled
}

export const dispatchChangeHandlers = async <T extends BaseModel>(
  handlers: ChangeHandler<T>[],
  ctx: TriggerContext<T>
): Promise<ChangeHandlerResult[]> => {
  const results: ChangeHandlerResult[] = []

  for (const handler of handlers) {
    const start = Date.now()

    if (!isEnabled(handler.enabled)) {
      results.push({ name: handler.name, status: 'disabled', matched: 0, durationMs: 0 })
      continue
    }

    const matched = ctx.newRecords.filter(record =>
      handler.shouldRun(record, ctx.mapOldRecord[record.UID], ctx)
    )

    if (!matched.length) {
      results.push({ name: handler.name, status: 'skipped', matched: 0, durationMs: Date.now() - start })
      continue
    }

    try {
      await handler.run(matched, ctx)
      results.push({
        name: handler.name,
        status: 'ok',
        matched: matched.length,
        durationMs: Date.now() - start
      })
    } catch (error) {
      const message = (error as Error).message
      console.error(`[change-handler:${handler.name}] failed`, {
        error: message,
        matchedIds: matched.map(r => r.UID)
      })
      results.push({
        name: handler.name,
        status: 'failed',
        matched: matched.length,
        durationMs: Date.now() - start,
        error: message
      })
    }
  }

  return results
}
```

### Usage — colocate handlers, registry, and route handler in one file

Keep all reactions for a given object operation in a single file. Read top-to-bottom: change handlers → registry → route handler.

```typescript
// src/handlers/job-handler.ts
import { ChangeHandler } from './types'
import { dispatchChangeHandlers } from './dispatch-change-handlers'
import { createTriggeredActionHandler } from './triggered-action-handler'
import { ConfigurationVariables } from '../utils/configuration-variables'

// --- Change handlers ---

const statusChangeHandler: ChangeHandler<Jobs> = {
  name: 'status-change',
  shouldRun: (newRec, old) => old != null && old.JobStatus !== newRec.JobStatus,
  run: async (jobs) => {
    await processStatusChanges(jobs)
  }
}

const addressChangeHandler: ChangeHandler<Jobs> = {
  name: 'address-change',
  shouldRun: (newRec, old) =>
    old != null && old.Address !== newRec.Address && newRec.Address != null,
  run: async (jobs) => {
    await updatePostalCodes(jobs)
  }
}

const regionChangeHandler: ChangeHandler<Jobs> = {
  name: 'region-change',
  // Feature flag — evaluated at dispatch time (after initConfigVars has run)
  enabled: () => ConfigurationVariables.ENABLE_JOB_REGION_CHANGE_HANDLER,
  shouldRun: (newRec, old) => old != null && old.RegionId !== newRec.RegionId,
  run: async (jobs) => {
    await reassignRegion(jobs)
  }
}

// --- Registry ---

const jobUpdateChangeHandlers: ChangeHandler<Jobs>[] = [
  statusChangeHandler,
  addressChangeHandler,
  regionChangeHandler
]

// --- Route handler ---

export const afterUpdateJobHandler = createTriggeredActionHandler<Jobs>(
  'Jobs',
  async ({ data: triggerContext }) => {
    const results = await dispatchChangeHandlers(jobUpdateChangeHandlers, triggerContext)
    const failed = results.filter(r => r.status === 'failed')

    return {
      // Non-2xx so the platform retries; any 2xx (even 207) counts as success and
      // silently drops the failures. Retries re-run the whole payload — keep handlers idempotent.
      status: failed.length ? 500 : 200,
      body: {
        operation: 'UPDATE',
        totalRecords: triggerContext.newRecords.length,
        changeHandlers: results
      }
    }
  }
)
```

### Feature flags via `ConfigurationVariables`

The `enabled` field can be a static boolean **or** a function. Use the function form when reading from `ConfigurationVariables`: the registry literal is evaluated at module load — **before** `initConfigVars(skedContext)` runs inside the request — so a non-function `enabled` captures the field's **default** value and never sees the tenant-specific configuration.

| Form | When evaluated | Works with ConfigurationVariables? |
| --- | --- | --- |
| `enabled: true` | Module load | N/A — literal value |
| `enabled: ConfigurationVariables.X` | **Module load** ❌ | No — captures the **default**, not the tenant value (read before `initConfigVars()`) |
| `enabled: () => ConfigurationVariables.X` | **Dispatch time** ✅ | Yes — runs after `initConfigVars()` |

**1. Declare the config var in `sked.proj.json`:**

```json
{
  "settings": {
    "configVars": [
      {
        "name": "ENABLE_JOB_REGION_CHANGE_HANDLER",
        "configType": "plain-text",
        "description": "Toggle the region-change handler in afterUpdateJobHandler",
        "default": "true"
      }
    ]
  }
}
```

**2. Wire it through `ConfigurationVariables`:**

```typescript
// src/utils/configuration-variables.ts
import { SkedContext } from '@skedulo/function-utilities'

export class ConfigurationVariables {
  static ENABLE_JOB_REGION_CHANGE_HANDLER: boolean = true

  static init(skedContext: SkedContext): void {
    const raw = skedContext?.configVars?.getVariableValue('ENABLE_JOB_REGION_CHANGE_HANDLER')
    ConfigurationVariables.ENABLE_JOB_REGION_CHANGE_HANDLER = raw !== 'false'
  }
}

export const initConfigVars = (skedContext: SkedContext) =>
  ConfigurationVariables.init(skedContext)
```

**3. Call `initConfigVars(skedContext)` once in `handler.ts`** before route dispatch.

**4. Reference the flag lazily** in the `ChangeHandler` as shown above: `enabled: () => ConfigurationVariables.ENABLE_JOB_REGION_CHANGE_HANDLER`.

### What this buys you

| Concern | Solution |
| --- | --- |
| Error isolation | Each handler wrapped in try/catch — one failure doesn't block others |
| Observability | Per-handler logs, name + matched IDs on failure; response body includes per-handler status, count, duration |
| No predicate boilerplate | Dispatcher filters records; `run()` receives only matched ones |
| Feature flags | `enabled` field, optionally lazy-evaluated against `ConfigurationVariables` |
| Declarative overview | Registry array reads like a table of contents |
| Partial-failure signaling | Returns a non-2xx (500) when any handler failed so the platform retries; 200 only when all succeed, with a per-handler breakdown |
| Testability | Each handler is a plain object — `shouldRun` and `run` testable independently |

### Naming convention to avoid "Handler" overload

Both the route handler and the sub-handlers contain the word "Handler". Disambiguate with a prefix convention:

- Route-registered: `<operation><Object>Handler` → `afterUpdateJobHandler`
- Sub-handlers: `<field>ChangeHandler` → `statusChangeHandler`
- Registry arrays: `<object><Operation>ChangeHandlers` (plural) → `jobUpdateChangeHandlers`

---

## Part 6: Route Registration

### Path convention

```text
POST /triggered-action/{entity-action}
```

Examples:

- `/triggered-action/job-after-insert`
- `/triggered-action/job-after-update`
- `/triggered-action/job-after-delete`
- `/triggered-action/job-allocation-after-update`
- `/triggered-action/account-after-upsert`

### Registering routes

```typescript
// src/routes/job.ts
import { FunctionRoute } from '@skedulo/sdk-utilities'
import { afterInsertJobHandler, afterUpdateJobHandler } from '../handlers/job-handler'

export function getJobRoutes(): FunctionRoute[] {
  return [
    { method: 'post', path: '/triggered-action/job-after-insert', handler: afterInsertJobHandler },
    { method: 'post', path: '/triggered-action/job-after-update', handler: afterUpdateJobHandler },
  ]
}
```

The manifest `action.url` must match exactly:

```json
"url": "{{SKEDULO_API_URL}}/function/my-function/my-function/triggered-action/job-after-update"
```

---

## Part 7: Common Patterns

### Guard: skip if no relevant records

Always return 200 early when nothing needs processing — returning non-2xx causes the platform to log an error:

```typescript
if (!jobsToProcess.length) {
  return { status: 200, body: { message: 'No relevant records, skipping' } }
}
```

### Idempotency check

Triggered actions may be retried. Check if work was already done:

```typescript
const existing = await relatedService.query([{
  conditions: [['SourceJobId', Operator.IN, newRecords.map(j => j.UID)]]
}])

const alreadyProcessedIds = new Set(existing.map(r => r.SourceJobId))
const unprocessed = newRecords.filter(j => !alreadyProcessedIds.has(j.UID))
```

### Batch mutations

```typescript
const updates = newRecords.map(job => ({
  UID: job.UID,
  ProcessedAt: new Date().toISOString()
}))

await jobService.save(updates)
```

### Error handling

```typescript
try {
  await processRecords(triggerContext.newRecords)
  return { status: 200, body: { processed: triggerContext.newRecords.length } }
} catch (error) {
  console.error('Triggered action failed', {
    error: (error as Error).message,
    ids: triggerContext.newRecords.map(r => r.UID)
  })
  return { status: 500, body: { error: 'Processing failed' } }
}
```

---

## Part 8: CLI Deployment

Use the Skedulo CLI to deploy, inspect, and delete triggered actions on a tenant. All commands accept `-a <alias>` to target a specific tenant.

### ⚠️ Always ask for the tenant alias first

Before running any CLI command that writes to a tenant, **ask the user for their tenant alias**. This prevents accidentally deploying to the wrong environment.

```text
What is your tenant alias? (e.g. your-tenant/your-team-name, my-org-staging)
```

Then use it with `-a <alias>` in every command.

---

### Upsert (create or update)

Deploy a triggered action from a manifest file. Use this for both first-time creation and updates:

```bash
sked artifacts triggered-action upsert -f src/triggered-actions/job-after-update.triggered-action.json -a <alias>
```

Flags:

| Flag | Required | Description |
| --- | --- | --- |
| `-f, --filename` | Yes | Path to the manifest JSON file |
| `-a, --alias` | Recommended | Tenant alias to deploy to |
| `--name` | No | Override the triggered action name |
| `-w, --wait` | No | Timeout in seconds (default: 900) |

To deploy all triggered actions in a directory at once:

```bash
for f in src/triggered-actions/*.triggered-action.json; do
  sked artifacts triggered-action upsert -f "$f" -a <alias>
done
```

---

### List

View all triggered actions on a tenant:

```bash
sked artifacts triggered-action list -a <alias>

# Filter by name
sked artifacts triggered-action list -a <alias> --filter name=job

# Output as JSON
sked artifacts triggered-action list -a <alias> --json
```

---

### Get

Fetch the current state of a specific triggered action and save it locally:

```bash
sked artifacts triggered-action get --name job-after-updated -a <alias>

# Save to a specific directory
sked artifacts triggered-action get --name job-after-updated -a <alias> -o src/triggered-actions/
```

Useful for inspecting what is currently deployed on a tenant, or pulling down the state before making changes.

---

### Delete

Remove a triggered action from a tenant by name:

```bash
sked artifacts triggered-action delete --name job-after-updated -a <alias>
```

---

### Typical deployment workflow

```bash
# 1. Ask user: "What is your tenant alias?"
#    e.g. alias = your-tenant/your-team-name

# 2. Deploy the connected function first
sked artifacts function upsert -f src/functions/my-function/state.json -a your-tenant/your-team-name

# 3. Deploy the triggered action manifest
sked artifacts triggered-action upsert \
  -f src/triggered-actions/job-after-update.triggered-action.json \
  -a your-tenant/your-team-name

# 4. Verify it deployed
sked artifacts triggered-action list -a your-tenant/your-team-name --filter name=job-after-update
```

---

## Checklist

Before deploying a triggered action:

- [ ] Tenant alias confirmed with the user
- [ ] Manifest file exists in `src/triggered-actions/`
- [ ] `trigger.filter` is as specific as possible to avoid unnecessary invocations
- [ ] `action.query` includes all fields the handler reads
- [ ] `action.previousFields` is set for UPDATE/DELETE handlers (omitted for INSERT-only)
- [ ] `sked-function-execution-type: async` header is set for slow operations
- [ ] Handler guards against empty `newRecords` / irrelevant changes
- [ ] Handler is idempotent (safe to retry)
- [ ] Route path in manifest URL matches exactly the path registered in routes
- [ ] Deferred trigger handlers re-check record state at execution time (don't trust the filter's snapshot)
- [ ] Upsert handlers handle `isInsert` / `isUpdate` branching explicitly if operations differ
- [ ] Connected function deployed before the triggered action manifest
