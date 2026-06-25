---
name: triggered-actions-developer
description: This skill enables Claude to author, edit, review, and deploy Skedulo Pulse Triggered Actions — event-driven automations that fire on object modifications (INSERT/UPDATE/DELETE), platform events (async task completion, recurring schedule events), and deferred timers anchored to an object's DateTime field. Covers the canonical TriggeredAction state-file shape, the 2 trigger types (`object_modified`, `event`), the 2 action types (`call_url`, `send_sms`), EQL filter syntax with `Current.`/`Previous.` prefixes, GraphQL query payloads including `previousFields`, Mustache template helper functions (`{{ first }}`, `{{ formatDateTime }}`), configuration variables, the reserved `{{ SKEDULO_USER_TOKEN }}` header, and the platform rules that cause `sked artifacts triggered-action upsert` to reject otherwise-valid-looking JSON.
---
# Skedulo Pulse Triggered Actions Skill

## What is a Triggered Action in Pulse?

A Triggered Action is a **reactive, rule-driven** server-side automation that fires when something happens in the tenant — a record is inserted / updated / deleted, an asynchronous platform task completes, or a recurring-schedule event finishes. It is the Pulse equivalent of Salesforce's process automation (Flow / Process Builder / Apex trigger), with one important caveat: a Triggered Action does NOT execute arbitrary user code in-tenant. It performs ONE of two side effects:

- **`call_url`** — HTTP POST to an HTTPS endpoint with a GraphQL query payload
- **`send_sms`** — Mustache-templated SMS to one or more phone numbers

For richer logic, the `call_url` target is typically a Connected Function (Pulse) or external service; the Triggered Action is the wiring that decides *when* to call it and *what data* to send.

## Triggered Actions vs Webhooks (when to use which)

Both are configured against the same `/triggered_actions` API surface — Webhooks are actually implemented internally as a specialised flavour of Triggered Action. Default to Triggered Actions for all event-driven work; reach for Webhooks ONLY when one of these two features is required:

| Feature                                                       | Triggered Action | Webhook            |
| ------------------------------------------------------------- | ---------------- | ------------------ |
| Fire on object INSERT / UPDATE / DELETE                       | ✅               | ✅                 |
| Include previous-values payload                               | ✅               | ✅                 |
| Retrieve extra data via GraphQL query after the trigger fires | ✅               | ❌                 |
| Send an SMS as the action                                     | ✅               | ❌                 |
| Fire after a time offset (deferred)                           | ✅               | ✅                 |
| Fire on **inbound SMS**                                 | ❌               | ✅ — webhook-only |
| Fire on a **cron schedule**                             | ❌               | ✅ — webhook-only |

If your use case isn't cron-based or inbound-SMS-based, it's a Triggered Action.

## Authentication & Prerequisites

Triggered Actions require:

- **API access token** in the `Authorization: Bearer <token>` header for every `/triggered_actions` API call. Tokens are minted in Pulse Web → Settings → API Tokens. The `sked` CLI handles this automatically once you've run `sked tenant login --alias <alias>` — the alias is your shorthand for the tenant + stored token.
- **HTTPS only.** Skedulo refuses non-HTTPS URLs in the `/triggered_actions` API itself and in any `action.url` for `call_url` actions. There is no `http://` exception even for localhost / dev — use ngrok or similar for local-tunnel testing.
- **Skedulo for Salesforce tenants need an API user** configured for the team. Without it, the platform cannot perform reads/writes back to the SF side from the triggered action's GraphQL `query`. Configure via Pulse Web → Settings → API user, per environment (sandbox + production).
- **Change-event tracking** must be enabled on any object that an `object_modified` trigger fires on (see [Trigger Type 1: `object_modified`](#trigger-type-1-object_modified) for the enablement steps). Standard objects + custom objects created on or after 2024-05-10 are tracked automatically; older custom objects need manual enablement.

## CLI Surface

```bash
# List existing triggered actions in a tenant
sked artifacts triggered-action list -a <alias>

# Pull a triggered action's state file into the local workspace
sked artifacts triggered-action get -a <alias> --name <ActionName> -o <outputdir>

# Create OR update from a state file (deploys the local file to the tenant)
sked artifacts triggered-action upsert -a <alias> -f <state-file>

# Delete a triggered action from the tenant by name
sked artifacts triggered-action delete -a <alias> --name <ActionName>
```

All write commands (`upsert`, `delete`, the deprecated `create` / `update`) accept `-w <seconds>` (default `900`) to control the max wait before the CLI gives up on a slow tenant. Bump this in CI pipelines when upserts occasionally hang past 15 minutes.

> Note: `create` and `update` are deprecated subcommands kept for backward compat — always use `upsert`, which handles both cases idempotently by `name`.

## Workspace Layout

```text
<your-project>/
├── SPEC.md                                                # spec, feature checklist
└── src/
    └── triggered-actions/
        ├── JobStatusChangedSMS.triggered-action.json
        ├── JobStatusChangedCallout.triggered-action.json
        ├── JobStartReminder.triggered-action.json
        └── BulkUserImportNotification.triggered-action.json
```

Each Triggered Action is a single JSON file at `src/triggered-actions/<ActionName>.triggered-action.json`. The filename's `<ActionName>` MUST match the `name` field inside the JSON exactly — `sked artifacts triggered-action get` emits files in this convention, so authored files round-trip cleanly with retrieve.

No parent / child relationship exists between triggered actions — each is independent, and deploy order doesn't matter. (Contrast with object models where custom objects must deploy before their fields.)

## Canonical State File Shape

```json
{
  "metadata": { "type": "TriggeredAction" },
  "enabled": true,
  "name": "JobStatusChangedSMS",
  "description": "Send SMS to contact when JobStatus changes",
  "trigger": { ... },
  "action": { ... }
}
```

### Top-level keys

| Key               | Required      | Notes                                                                                                                                                    |
| ----------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `metadata.type` | ✅            | Must be the literal string `"TriggeredAction"`                                                                                                         |
| `enabled`       | ✅            | Boolean. `false` keeps the artifact in the tenant but pauses execution — useful for staging.                                                          |
| `name`          | ✅            | PascalCase string. Must match the filename's `<ActionName>` portion. Uniqueness is enforced by the tenant.                                             |
| `description`   | ⚠️ Optional | Free-form. Strongly recommended for traceability — surfaces in `sked artifacts triggered-action list` and is the first thing the next engineer reads. |
| `trigger`       | ✅            | See **Trigger Types** below.                                                                                                                       |
| `action`        | ✅            | See **Action Types** below.                                                                                                                        |
| `customFields`  | ⚠️ Optional | Tenant-set metadata; only populated by the platform on retrieve. Do not author.                                                                          |

`enabled: false` deploys a paused Triggered Action — handy when you want the metadata in place before flipping it on.

## Trigger Types

There are **2 trigger types**: `object_modified` and `event`.

### Trigger Type 1: `object_modified`

Fires when a tenant data record is inserted, updated, or deleted on a specific object (schema). Tracking must be enabled on the object — standard objects are tracked by default; custom objects created on or after 2024-05-10 are tracked automatically; older custom objects require manual tracking enablement via two API calls:

```bash
# 1. Find the objectId for the custom schema
curl -X POST 'https://api.skedulo.com/custom/schemas' \
  -H "Authorization: Bearer $AUTH_TOKEN"

# 2. Enable tracking on that schema by objectId
curl -X POST "https://api.skedulo.com/custom/standalone/schema/{objectId}/track" \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

Skedulo for Salesforce tenants need additional Salesforce-side configuration to enable change-event tracking for all objects — coordinate with your SF admin.

```json
"trigger": {
  "type": "object_modified",
  "schemaName": "Jobs",
  "filter": "Current.JobStatus != Previous.JobStatus",
  "deferred": { "fieldName": "Start", "offset": -3600000 }
}
```

| Key            | Required                              | Notes                                                                                                                                                     |
| -------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`       | ✅                                    | Literal `"object_modified"`                                                                                                                             |
| `schemaName` | ✅                                    | Pulse object name (e.g. `Jobs`, `Resources`, `Accounts`, `sked_AccountNote`). Use the GraphQL type name, not the underlying Salesforce table name. |
| `filter`     | ✅ — MANDATORY for Triggered Actions | EQL expression — see Filter EQL below. Unlike webhooks (where filter is optional), Triggered Actions reject a missing or empty filter.                   |
| `deferred`   | ⚠️ Optional                         | See Deferred Triggers below.                                                                                                                              |

#### Filter EQL (object_modified)

The filter is a special variant of EQL relevant to change events. It MUST reference fields via the `Current.` or `Previous.` parent and MAY reference the operation that caused the change:

```text
Current.JobStatus != Previous.JobStatus
Current.JobStatus == 'Complete' AND Previous.JobStatus != 'Complete'
Operation == 'INSERT' AND Current.Type == 'Inspection'
Operation == 'DELETE' AND Previous.Approved == true
Current.Region.Name == 'Sydney'
```

Rules:

- `Operation` (no prefix) is one of `INSERT`, `UPDATE`, `DELETE`
- `Current.<Field>` is the post-change value. Always available on INSERT and UPDATE; undefined on DELETE.
- `Previous.<Field>` is the pre-change value. Always available on UPDATE and DELETE; undefined on INSERT.
- Dotted lookup paths are supported (`Current.Region.Name`)
- String literals use single quotes
- Booleans are `true` / `false`
- `null` checks: `Current.<Field> != null`

Best practice: write filters that constrain narrowly. A filter of `Operation == 'UPDATE'` against a high-traffic object (Jobs, JobAllocations) fires thousands of times a day for fields you don't care about — combine with field-equality conditions.

#### Deferred Triggers

```json
"deferred": {
  "fieldName": "Start",
  "offset": -3600000
}
```

The `deferred` sub-block postpones execution to a future instant relative to a DateTime field's value.

- `fieldName` — the anchor DateTime field on the trigger schema (e.g. `Jobs.Start`, `Jobs.End`, `Activities.ActualEnd`, custom `*__c` DateTime fields)
- `offset` — milliseconds. **Negative = before** the anchor; positive = after. Examples:
  - `-86400000` — 24 hours before
  - `-3600000` — 1 hour before
  - `300000` — 5 minutes after
  - `0` — at the anchor time exactly

The offset may also be a dynamic object that reads a duration from a per-record field, with a default fallback:

```json
"deferred": {
  "fieldName": "Start",
  "offset": {
    "fieldName": "NotificationLeadTimeMs",
    "default": 600000
  }
}
```

When the anchor field or offset field changes on a record, the platform reschedules the deferred fire — you don't have to handle that manually.

Critical: when the anchor is `CreatedDate` or `LastModifiedDate`, set `offset >= 5000` (5 seconds). There is a small delay between the data change being processed and the deferred-trigger scheduler picking it up — shorter offsets race against the platform's internal lag and may never fire.

### Trigger Type 2: `event`

Fires on a predefined platform event. Event-type triggers use a `filter` (mandatory for all Triggered Actions) to select which platform events fire the action, almost always with a `type == '<event-name>'` clause.

```json
"trigger": {
  "type": "event",
  "filter": "type == 'optimization'"
}
```

| Key      | Required | Notes                                                                                                                                          |
| -------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`   | ✅       | Literal `"event"`                                                                                                                              |
| `filter` | ✅       | EQL expression. Almost always `type == '<event-name>'`. The filter selects which platform events fire this action — events don't fan out auto. |

Event triggers do NOT support `schemaName` or `deferred` blocks — the event fires when the platform emits it, not relative to a record's anchor field.

#### Known event types

| `filter` clause                       | Fires when                                                                                                                                                                                                                                                            |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type == 'optimization'`              | An optimization run completes (success or failure). Use case: invoke a Connected Function that inspects the optimization result and dispatches jobs (or re-queues them).                                                                                              |
| `type == 'async_task_completed'`      | An asynchronous platform task completes. The upstream doc lists three sub-tasks (`bulk_user_import`, `copy_schedule`, `apply_schedule_template`); for stricter filtering on a specific sub-task, retrieve an existing TA from your tenant to confirm the EQL syntax.  |
| `type == 'recurring_schedule'`        | A recurring-schedule update finishes. Manually fired via `POST /recurring/schedules/jobs/event`.                                                                                                                                                                      |

Event types you discover in your tenant may extend this list. Safest path before authoring a new event-trigger: retrieve an existing TA from a non-prod tenant via `sked artifacts triggered-action get --name <ExistingTA> --alias <alias> -o <out>` to confirm the exact filter.

#### Actions with `event` triggers

Event triggers can use either action type (`call_url` or `send_sms`), but **unlike `object_modified`, event triggers do NOT have record context** — there's no parent schema to query against. Consequences:

- `action.query` and `action.previousFields` are typically `null` for event triggers — set them explicitly to `null` so the JSON round-trips cleanly with `sked artifacts triggered-action get`.
- `send_sms` templates can't interpolate per-record field values (no `{{ Contact.FirstName }}` paths) — only static text + configuration variables work.

A typical `event` + `call_url` shape:

```json
{
  "metadata": { "type": "TriggeredAction" },
  "enabled": true,
  "name": "OptimizationFinishHandler",
  "trigger": {
    "type": "event",
    "filter": "type == 'optimization'"
  },
  "action": {
    "type": "call_url",
    "url": "{{ <CONFIG_VAR_URL> }}/function/<function-name>/<route>",
    "headers": {
      "Content-Type": "application/json",
      "Authorization": "Bearer {{ <CONFIG_VAR_TOKEN> }}"
    },
    "query": null,
    "previousFields": null
  }
}
```

To test a `recurring_schedule` event handler, fire the event manually:

```bash
curl -X POST 'https://api.skedulo.com/recurring/schedules/jobs/event' \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

## Action Types

There are **2 action types**: `call_url` and `send_sms`. The `type` of an existing Triggered Action is IMMUTABLE — `sked artifacts triggered-action upsert` will reject any attempt to switch from `call_url` to `send_sms` or vice versa. Delete and recreate if you genuinely need to change action type.

### Action Type 1: `call_url`

HTTP POST to a URL with a GraphQL query payload.

```json
"action": {
  "type": "call_url",
  "url": "{{ JOB_STATUS_CALLBACK_URL }}",
  "headers": {
    "X-Skedulo-User-Token": "{{ SKEDULO_USER_TOKEN }}",
    "X-API-Key": "{{ JOB_STATUS_API_KEY }}"
  },
  "query": "{ UID Name JobStatus Description Region { Name } JobAllocations(filter: \"Status != 'Deleted'\") { UID Status Resource { Name } } }",
  "previousFields": "{ JobStatus Duration }"
}
```

| Key                | Required                                | Notes                                                                                                                                                                                                               |
| ------------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`           | ✅                                      | Literal `"call_url"`                                                                                                                                                                                              |
| `url`            | ✅                                      | **MUST be HTTPS** — `http://` is rejected. Supports `{{ CONFIG_VAR }}` templates.                                                                                                                        |
| `headers`        | ⚠️ Optional                           | Map of string → string. Supports `{{ CONFIG_VAR }}` templates and the reserved `{{ SKEDULO_USER_TOKEN }}`.                                                                                                     |
| `query`          | ⚠️ Optional (for `object_modified`) | A GraphQL selection set (no `query { ... }` wrapper — just `{ ... }`). Executed against the trigger's `schemaName` at action-fire time and embedded under `data.<lowercased-schemaName>` in the POST body. |
| `previousFields` | ⚠️ Optional                           | A FLAT GraphQL selection set listing fields whose pre-change values to include under `previous`. **Cannot contain nested objects.**                                                                         |

#### Headers Skedulo sets on outgoing `call_url` requests

In addition to any `headers` you author, Skedulo always sends:

| Header                         | Value / Purpose                                                                                                                                                                |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `User-Agent`                   | Literal `Skedulo` — identifies the caller.                                                                                                                                     |
| `Skedulo-Triggeredactionlogid` | Per-request log ID (changes on every fire). Use it to correlate the receiver's logs with `GET /triggered_actions/logs` server-side. Webhooks also carry this header.           |
| `Skedulo-Triggeredactionid`    | The Triggered Action's configuration UID — **stable per TA across every fire**. The receiver should key idempotency / dedup logic off this header + the per-record `UID`.      |

The receiving Connected Function (or external service) should NOT assume a particular `Content-Type` from the platform side — Skedulo sets the request body as JSON but doesn't always send `application/json` in the request. Parse the body defensively.

#### Payload format (object_modified → call_url)

For each record that triggered the action, the platform sends a JSON array element shaped like:

```text
{
  "data":      { "<schemaName lowercased>": { ...query result... } },  // present for INSERT and UPDATE
  "previous":  { ...previousFields snapshot... },                       // present for UPDATE and DELETE
  "operation": "INSERT" | "UPDATE" | "DELETE"
}
```

Multiple record changes within a short time window are batched into a single POST containing an array of these objects. A typical 3-record batch (one INSERT, one UPDATE, one DELETE):

```json
[
  {
    "data": {
      "jobs": {
        "UID": "00145e74-4acb-4369-89a1-37544f2a4d4f",
        "Name": "JOB-6633",
        "JobStatus": "Queued",
        "Duration": 60
      }
    },
    "operation": "INSERT"
  },
  {
    "previous": { "Duration": 200, "JobStatus": "Queued" },
    "data": {
      "jobs": {
        "UID": "00146198-6242-4fe0-9b53-bd4a55a6bc22",
        "Name": "JOB-6629",
        "JobStatus": "Queued",
        "Duration": 20
      }
    },
    "operation": "UPDATE"
  },
  {
    "previous": {
      "Duration": 60,
      "JobStatus": "Queued",
      "UID": "001472cd-87ae-464e-bc15-d4e1855aa736"
    },
    "operation": "DELETE"
  }
]
```

INSERT events have no `previous` block. DELETE events have no `data` block, but the platform auto-injects `previous.UID` so you can identify which record was deleted.

**`previousFields` returns ALL requested fields, even when null or unchanged.** This is intentional — receivers diffing pre/post values get a complete snapshot of the watched fields, not just the deltas. Don't write logic that assumes "field present in `previous` ⇒ field changed".

The `query` is executed immediately before the HTTP call — it reflects the data *at action-fire time*, not at change-event time. (Webhooks do it the other way.) This matters for deferred actions: by the time a 1-hour-after-Start action fires, the job may have been edited again.

#### Updating a triggered action via the API (PATCH semantics)

`sked artifacts triggered-action upsert -f <file>` always sends the full state file, so authors don't normally hit this. But when calling `PATCH /triggered_actions/{id}` directly via the API, the merge semantics are:

- **Top-level fields** (`name`, `enabled`, `customFields`) merge — include only what changes.
- **`trigger` and `action` blocks** REPLACE wholesale when included. Sending `trigger: { filter: "Current.X != Previous.X" }` without `trigger.type` AND `trigger.schemaName` returns `400 field_error "Missing required field"` on `.trigger.type`.

When using the CLI (`upsert`), this isn't a concern — the local state file is sent in full.

#### `{{ SKEDULO_USER_TOKEN }}`

A reserved header template token. When the trigger fired due to a user-initiated change, the platform substitutes the initiating user's access token at fire time. Useful when the call_url target is a Connected Function or external service that needs to act *as* the initiating user (respecting their permissions and audit identity).

`SKEDULO_USER_TOKEN` is also a reserved configuration-variable name — you cannot create a config var with this name.

#### Configuration variables `{{ FOO_BAR }}`

Configuration variables are tenant-scoped values managed in Pulse Web → Settings → Configuration variables. Reference them with `{{ VAR_NAME }}` (note the spaces inside the braces — they ARE significant in some older clients; use spaced form to be safe).

Supported locations:

- ✅ `action.url`
- ✅ `action.headers` (any header value)

NOT supported:

- ❌ `action.query` (GraphQL query body — config var substitution does not run here)
- ❌ `action.template` (send_sms Mustache template — config var substitution does not run here; the `{{ X }}` syntax in templates is for EQL field interpolation, not config vars)

### Action Type 2: `send_sms`

> ⚠️ **Billing notice**: SMS is a metered, fee-bearing service. Every fired `send_sms` action incurs per-message charges on top of the base subscription — verify the customer's SMS pricing tier in the SOW before scaling a high-frequency trigger. Filters that fire on broad object events (`Operation == 'UPDATE'` against `Jobs`) can rack up thousands of SMS in a single day.

```json
"action": {
  "type": "send_sms",
  "to": { "fieldName": "Contact.Mobile" },
  "template": "Hi {{ Contact.FirstName }}, your job {{ Name }} is now {{ JobStatus }} starting at {{ formatDateTime Start }}."
}
```

| Key          | Required | Notes                                                                                                                                                                      |
| ------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`     | ✅       | Literal `"send_sms"`                                                                                                                                                     |
| `to`       | ✅       | Either `{ "numbers": ["+61400000000", ...] }` (static phone list) OR `{ "fieldName": "Contact.Mobile" }` (EQL path on the trigger object resolving to a phone string). |
| `template` | ✅       | Mustache-style template. EQL field names interpolate; built-in helper functions available — see below.                                                                    |

#### Template EQL field interpolation

`{{ FieldName }}` resolves to the value of `FieldName` on the trigger object. Dotted paths resolve through lookups: `{{ Contact.FirstName }}`, `{{ Account.Region.Name }}`.

If a field is missing on the record, it renders as an empty string — be defensive in template wording.

#### Auto-formatting of Date & time fields

When a DateTime field (e.g. `Start`) appears directly in the template, it is auto-formatted using the trigger object's `Timezone` field (case-insensitive). If `Timezone` is `"America/Los_Angeles"`, `{{ Start }}` renders as `"Dec 25, 2:30 AM PST"`. If no `Timezone` field exists or it's invalid, the time renders in GMT.

#### Template helper functions

##### `{{ first <field1> <field2> ... [default] }}`

Returns the value of the first non-null field; if none are set, returns the optional default string.

```text
Please call {{ first Contact.Mobile Contact.OtherPhone "our office" }} to confirm.
```

##### `{{ formatDateTime <DateTimeField> [TimezoneField] [default] [pattern] }}`

Explicit DateTime formatting with optional timezone override, default-when-missing string, and custom pattern.

```text
Starts at {{ formatDateTime Start }}                                  # uses Timezone field
Starts at {{ formatDateTime Start CustomTz }}                         # uses CustomTz field
Starts at {{ formatDateTime Start "" "hh:mma" }}                      # custom pattern
Starts at {{ formatDateTime Start "" "No time set" }}                 # default if Start is null
```

If `<DateTimeField>` resolves to an invalid datetime, the action FAILS and the SMS is not sent — bad data short-circuits delivery.

#### Retries & timeouts (both action types)

HTTP `call_url` actions have a **25-second request timeout** — responses that take longer are considered timed out and retried.

Both action types use an exponential backoff schedule, but the per-retry delays differ slightly:

| Retry # | `call_url` delay | `send_sms` delay |
| ------- | ---------------- | ---------------- |
| 1       | 5 seconds        | 5 seconds        |
| 2       | 30 seconds       | 30 seconds       |
| 3       | 5 minutes        | 5 minutes        |
| 4       | 30 minutes       | 15 minutes       |
| 5       | 3 hours          | N/A              |

`call_url` actions try up to **6 times total** (initial attempt + 5 retries). `send_sms` actions try up to **5 times total** (initial attempt + 4 retries). The retry-vs-immediate-fail distinction is the platform's, not yours to configure.

## Logs & Debugging

Every Triggered Action fire is logged. Webhooks share the same log surface — they're implemented as a flavour of Triggered Action under the hood.

### Fetch logs

```bash
# All logs (last 24h by default)
curl -X GET 'https://api.skedulo.com/triggered_actions/logs' \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Filter to one specific Triggered Action by ID
curl -X GET 'https://api.skedulo.com/triggered_actions/logs?sourceId=<TA_UID>' \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Filter to Webhooks only or Triggered Actions only
curl -X GET 'https://api.skedulo.com/triggered_actions/logs?isWebhook=false' \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

### Log entry shape

Each log entry includes the URL called, the request body, the response status + headers, the retry counter, and an `attempts[]` array showing prior failures with timestamps. Example for a `call_url` action that succeeded on retry 2 after a 502:

```text
{
  "id": 122886092,
  "sourceId": "<TA_UID>",
  "data": { "url": "...", "body": { "data": { "jobs": { ... } } }, "action_type": "call_url" },
  "retry": 1,
  "started": "2026-05-23T01:10:53Z",
  "completed": "2026-05-23T01:10:54Z",
  "result": { "type": "http_response", "status": 200, "headers": { ... } },
  "attempts": [
    { "attempted": "2026-05-23T01:10:48Z", "error": { "type": "http_response", "status": 502, "headers": { ... } } }
  ],
  "status": "success"
}
```

### Intermediate-stage logs for deferred Triggered Actions

A deferred `object_modified` Triggered Action produces **multiple log entries per fire** — typically three: one for scheduling the deferred task, one for the platform's internal `fetch_object` step, and one for the final `call_url` (or `send_sms`) action. When debugging "why didn't my deferred TA fire?", inspect ALL log entries for the TA, not just the action-stage one. Common failure mode: the scheduling stage succeeds but the field-anchor changes (e.g. `Start` is cleared on the record), causing the platform to drop the scheduled fire silently.

## Pulse Rules (the critical checklist)

These are the platform-enforced rules that cause `sked artifacts triggered-action upsert` to reject otherwise-valid-looking JSON, or cause silent runtime misbehaviour. The review-agent enforces all of them as Critical or High findings.

1. **`filter` is MANDATORY** for Triggered Actions. (Webhooks are different — they accept missing filter — but they're a different artifact.) Empty filter strings are also rejected. **Deferred Triggered Actions REQUIRE an additionally narrow filter** — every record matching the filter at upsert time schedules a future fire (the platform pre-computes the deferred fire slot), so a broad filter against `Jobs` or `JobAllocations` instantly schedules tens of thousands of future events.
2. **`object_modified` filter MUST reference fields via `Current.<Field>` or `Previous.<Field>`** — raw `<Field>` without a prefix is rejected. `Operation` is the only valid unprefixed token (matches one of `'INSERT'`, `'UPDATE'`, `'DELETE'`).
3. **`action.url` must be HTTPS** for `call_url` actions. `http://` is rejected at upsert.
4. **`previousFields` cannot contain nested objects** — flat field selection only. `{ Duration JobStatus Region { Name } }` is invalid; `Region` must come from the main `query` block, not `previousFields`.
5. **INSERT has no `previous`, DELETE has no `data`** — call_url targets that assume both will misbehave. The platform auto-injects `previous.UID` on DELETE so the target can identify the deleted record.
6. **Deferred offset >= 5000ms** when the anchor is `CreatedDate` or `LastModifiedDate`. Smaller offsets race the platform's internal change-processing lag.
7. **`action.type` is IMMUTABLE on update**. You cannot upsert a `call_url` action over an existing `send_sms` action — the API returns 400 `"Cannot change the type of the action"`. Delete + recreate when you genuinely need to switch.
8. **`{{ SKEDULO_USER_TOKEN }}` is a reserved configuration-variable name** — cannot be created as a regular config var. Use it only in `action.headers` values to inject the initiating user's access token.
9. **Configuration variables only substitute in `action.url` and `action.headers` for `call_url`**. Do NOT use `{{ MY_VAR }}` inside `action.query` or `send_sms` `action.template` — the substitution doesn't run there and the literal text leaks into the payload.
10. **Field names in `send_sms` templates must resolve on the trigger schema** (or via dotted lookup path). The review-agent verifies this against the GraphQL schema when an `--alias` is available.
11. **`enabled: false` deploys but doesn't fire** — use deliberately for staging; don't leave production triggers disabled by accident.
12. **Skedulo for Salesforce — `schemaName` references the registered Pulse type**, not the SF table. If you add a custom object on the SF side and want a Triggered Action to fire on it, register the object in Pulse Web → Settings → Data management → Custom fields per environment first; only then does the Pulse type name exist and become a valid `schemaName`.

## Common Patterns (the 5 starter templates)

The plugin ships 5 starter templates under `templates/`. Scaffold any of them via `/triggered-actions:build template:<name>`:

### `status-change-sms` — SMS on status change

Fire when a status field flips, send an SMS to a phone field on the record. Most common pattern. Variants: `JobStatus` change → contact, `Allocation.Status` change → resource.

### `status-change-callout` — POST on status change

Fire when a status field flips, POST a GraphQL-shaped payload to a configurable URL (typically a Connected Function or external system). Variants: `JobStatus == 'Complete'` → billing system, `JobStatus == 'InProgress'` → real-time dashboard.

### `deferred-reminder` — fire before/after an anchor DateTime

Fire some milliseconds before / after a record's anchor DateTime field. Variants: 1 hour before `Jobs.Start` → SMS to contact, 24 hours before `Jobs.Start` → marketing reminder, 5 minutes after `JobAllocations.ActualEnd` → call payroll system.

### `async-task-completed` — POST when bulk import / schedule operation completes

Fire on a platform `async_task_completed` event. Variants: `bulk_user_import` → notify data-ops Slack, `apply_schedule_template` → POST to schedule audit system.

### `optimization-finish` — POST when an optimization run completes

Fire on a platform `optimization` event (filter `type == 'optimization'`). Variants: optimization-result inspector → conditionally dispatch jobs, optimization metrics collector → POST to monitoring dashboard. Typical pattern is a `call_url` to a Connected Function that reads the optimization result and decides what to do next.

Each template contains `<PLACEHOLDER>` strings the init-agent walks through with the user, plus inline examples in the field comments.

## Skedulo for Salesforce note

On Skedulo for Salesforce projects (where Salesforce is the system of record and Pulse layers on top), Triggered Actions work the same — they're a Pulse artifact. Two things to remember:

1. **`schemaName` must be the registered Pulse type**, which may be slightly different from the SF API name. SF object `sked_AccountNote__c` → Pulse type `sked_AccountNote` (the `__c` suffix is dropped). SF field `Notes__c` → Pulse field `Notes`.
2. **Register the object + every field referenced by the TA** in Pulse Web → Settings → Data management → Custom fields, per environment (sandbox AND production). A TA that references an unregistered field fails at runtime with a GraphQL field-not-found error.
3. **Connector-driven writes (via the call_url target) fire SF triggers** by default. If your call_url target performs GraphQL mutations on the SF-mastered object, expect SF Apex triggers to run. Make those triggers idempotent — call_url retries on 5xx, and the same mutation can land twice.

## Authoring Workflow Recap

1. **Init session** — `/triggered-actions:build "<requirements>"` or `/triggered-actions:build template:<name>` or `/triggered-actions:build retrieve:<Name1>,<Name2> --alias <alias>`. Init agent scaffolds `SPEC.md` + `src/triggered-actions/`, then stops.
2. **Coding session** (new session) — `/triggered-actions:build`. Coding agent reads `SPEC.md`, generates the `.triggered-action.json` files, then auto-spawns the review agent via the SubagentStop hook.
3. **Review** — the review agent validates filter EQL syntax, GraphQL query shape, send_sms template field references, the Pulse Rules above, and (when an `--alias` is available) cross-checks against the live tenant GraphQL schema.
4. **Deploy** — `/triggered-actions:deploy --alias <alias>`. Explicit and non-autonomous. Per-file `sked artifacts triggered-action upsert -a <alias> -f <file>`.

The coding agent NEVER deploys autonomously. Deploy stays a deliberate, separate command.
