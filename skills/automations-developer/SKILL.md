---
name: automations-developer
description: This skill enables Claude to create, edit, and deploy Skedulo Pulse automations via the Automations REST API. Captures the full action/trigger vocabulary, the 9 undocumented schema corrections required to actually get automations to load, JSONata-in-Step-Functions gotchas, and proven workflow patterns. Use any time the user wants to author or edit an automation, debug a 400/500 from the Automations API, or translate a customer webhook/triggered-action into the automation platform.
---

# Skedulo Automations Developer Skill

## What this skill covers

Skedulo Automations are AWS Step Functions state machines authored as JSON, triggered by tenant data events, and saved through a REST API. This skill is the working reference for building them — schema, trigger types, action vocabulary, JSONata gotchas, and end-to-end workflow.

**Use this skill when:**
- Writing a new automation JSON
- Editing an existing automation
- Debugging a `400` or `500` from `POST /automations/`
- Translating a customer webhook / triggered-action / connected-function handler into an automation
- Designing automations during a discovery call and need to know what's possible

**Do NOT use this skill for:**
- Writing connected functions (use `connected-function-developer` instead)
- Building horizon-component UIs that consume automations (use `horizon-component-developer`)
- Direct AWS Step Functions work outside Skedulo's wrapper (most of what's here is Skedulo-specific)

---

## 1. Architecture in one paragraph

The Skedulo Automations service exposes a REST API on every tenant's base URL. Each automation is persisted as `{name, description, trigger, workflow, status}`. Triggers fire on platform change events (objectModified) — the runtime evaluates a trigger condition, then dispatches the workflow to an orchestration service. Tasks invoke a per-action handler. JSONata expressions wrapped in `{% ... %}` are evaluated by the platform's built-in JSONata engine. The platform auto-injects `QueryLanguage: "JSONata"` and an `Assign` block per Task; you don't set those.

---

## 2. Authentication & API endpoints

### Base URL

Per-tenant. Read from the tenant's Insomnia environment, the platform UI URL bar, or your CLI config. Format: `https://<tenant-host>` — automations live under `/automations/`.

```text
https://api.skedulo.com            # production tenants
```

### Auth

All requests use `Authorization: Bearer <jwt>`. Get the token from:
- The `sked` CLI: `sked auth print-token`
- An OAuth2 interactive flow against the tenant's OAuth2 endpoint

### Endpoints

| Method | Path | Purpose |
|--------|------|----------|
| `GET` | `/automations/` | List all automations on the tenant |
| `POST` | `/automations/` | Create an automation |
| `GET` | `/automations/<name>` | Fetch by URL-encoded name |
| `PUT` | `/automations/<name>` | Update (full replacement) |
| `DELETE` | `/automations/<id-or-name>` | Delete |
| `POST` | `/automations/<name>/enable` | Enable (status → enabled) |
| `POST` | `/automations/<name>/disable` | Disable (status → disabled) |
| `POST` | `/automations/<name>/execute` | Manually invoke for testing |
| `GET` | `/automations/logs` | Tail recent execution logs |
| `GET` | `/automations/actions` | Live list of available actions on this tenant |
| `GET` | `/automations/swagger/v3-json` | OpenAPI JSON for the full surface |

When in doubt, fetch `/automations/swagger/v3-json` — it's the source of truth.

---

## 3. Automation document shape

Required top-level shape for `POST /automations/`:

```json
{
  "name": "my-automation-name",
  "description": "What this does",
  "trigger": {
    "type": "objectModified",
    "config": {
      "objectType": "Jobs",
      "operations": ["Update"],
      "filter": "JobStatus == 'Complete'"
    }
  },
  "workflow": {
    "definition": {
      "StartAt": "FirstState",
      "States": { "FirstState": { "Type": "Succeed" } }
    }
  },
  "status": "disabled"
}
```

**Field-by-field:**

- `name` — unique within tenant; `^[A-Za-z0-9 \-._~]+$` only. Trimmed by the API.
- `description` — optional. Use it for the source-handler reference + maintainer notes.
- `trigger` — see §4. Must be present before `enable` succeeds.
- `workflow.definition` — Amazon States Language state machine. **Wrapped in `definition`**, not inline at `workflow`.
- `status` — `"enabled"` or `"disabled"`. **API defaults to `"enabled"`** if absent. **Always set explicitly to `"disabled"` for new loads** unless the user has confirmed they want it live.

---

## 4. Trigger types — what's implemented today

The trigger configuration supports two types, but only one is wired end-to-end:

### `objectModified` — IMPLEMENTED ✓

Fires on platform change events from any data-model record write.

```json
{
  "type": "objectModified",
  "config": {
    "objectType": "Jobs",
    "operations": ["Insert", "Update", "Delete"],
    "filter": "JobStatus != 'Cancelled'"
  }
}
```

- `objectType` — schema name (the GraphQL/data-model record type, e.g. `Jobs`, `Accounts`, `Resources`, `JobAllocations`, custom objects)
- `operations` — array of `Insert`, `Update`, `Delete`. At least one required.
- `filter` — **non-empty** EQL filter applied to the post-state. Use `UID != null` for "always". Cannot reference `Previous.X` (post-state only — see §10 for field-change detection workaround).

### `event` — DECLARED BUT NOT IMPLEMENTED ✗

`TriggerType.EVENT = "event"` exists in the enum and `vocabulary.md` lists it as supported. **It is not wired through.** The `CreateTriggerDto.config` only types `ObjectModifiedConfigDto`; there is no `EventConfigDto`. Posting an `event`-typed trigger fails 400 because the API still validates `config.objectType / operations / filter`. The runtime trigger flow only handles `SchemaChangeV2Event`.

If a user asks for an event-driven automation: explain that event triggers aren't supported yet and the customer code still needs to live in a connected function until the platform ships them.

### `deferred` and `scheduled` — NOT SUPPORTED

There is no offset-from-field deferred trigger and no cron-style scheduled trigger. Customer patterns that need these (job reminders, SLA escalations, daily/weekly cron, retry queues) cannot be expressed as automations today.

---

## 5. Action vocabulary

The platform ships ~34 actions across 8 categories. The canonical live list is available at `GET /automations/actions`.

### Quick reference (as of 2026-04)

| Category | Actions |
|----------|---------|
| **utility** | `echo` |
| **integration** | `http` |
| **data** | `query-record`, `graphql-query`, `create-record`, `update-records`, `delete-records` |
| **related-data** | `get-jobs-for-resource`, `get-contacts-for-job`, `get-account-tags`, `get-resources-on-job` |
| **work-management** | `create-job`, `cancel-jobs`, `lock-jobs`, `move-job-time`, `duplicate-job`, `copy-schedule`, `create-resource-requirement` |
| **allocations** | `allocate-job`, `deallocate-jobs`, `dispatch-resources` |
| **offers** | `create-job-offer`, `create-shift-offer`, `notify-job-offer`, `notify-shift-offer` |
| **notifications** | `send-sms`, `send-notification` |
| **scheduling** | `suggest-time`, `suggest-resources`, `suggest-region-for-job`, `geocode-address`, `calculate-travel-time`, `get-current-location`, `get-resources-within-distance` |

### Always check live first

The action set evolves. Before suggesting an action that isn't `http`/`echo`/the data CRUD trio, confirm it exists:

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/automations/actions" | jq -r '.[].name' | sort
```

### Most-common action argument shapes

| Action | Required args | Output shape |
|--------|---------------|---------------|
| `echo` | `message` | wrapped: `{result: {data: {message}}}` |
| `http` | `url` (also `method`, `headers`, `body`) | **NOT wrapped:** `{statusCode, headers, body}` directly |
| `query-record` | `objectType`, `id`, `fields[]` (dotted paths OK; **no hasMany**) | wrapped: `{result: {data: <record>}}` |
| `graphql-query` | `query`, `variables` | wrapped: `{result: {data: <gql-shape>}}` |
| `create-record` | `objectType`, `fields{}` | wrapped: `{result: {data: {uid}}}` |
| `update-records` | `objectType`, `ids[]`, `fields{}` | wrapped: `{result: {data: {success}}}` |
| `delete-records` | `objectType`, `ids[]` | wrapped: `{result: {data: {success}}}` |
| `send-sms` | `phoneNumber`, `countryCode`, `message`, `expectsReply` | wrapped |
| `send-notification` | `resourceId`, `message`, `protocol` | wrapped |

### Response wrapping rule

Almost every action wraps its payload via `actionResponseSchema()`:

```text
$<assignedVar>.result.data.<actual-data-shape>
```

`http` is the documented exception — its response is `{statusCode, headers, body}` directly without a `result` envelope. Reach for `body` directly: `$<assignedVar>.body`.

Data actions are wrapped via `actionResponseSchema()`. The `http` action is the documented exception — its response is defined inline without the wrapper envelope.

---

## 6. Workflow document shape (Amazon States Language)

The `workflow.definition` is a Step Functions state machine. The platform supports the standard ASL state types: `Task`, `Choice`, `Pass`, `Wait`, `Parallel`, `Map`, `Succeed`, `Fail`.

```json
{
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Type": "Task",
      "Resource": "action:query-record",
      "Arguments": { /* per-action input */ },
      "Next": "SecondState"
    },
    "SecondState": { "Type": "Succeed" }
  }
}
```

**Critical: do NOT set `QueryLanguage: "JSONata"` at the top level.** The service auto-injects it. Including it doesn't break loading but is redundant and gets stripped server-side anyway.

### Common state types

**`Task`** — invokes an action.

```json
{
  "Type": "Task",
  "Resource": "action:<action-name>",
  "Arguments": { /* input matching the action's required props */ },
  "Next": "<next-state>"
}
```

**`Choice`** — branching. Each rule has a `Condition` (a JSONata boolean expression) and a `Next`. Falls through to `Default` if no rule matches.

```json
{
  "Type": "Choice",
  "Choices": [
    {
      "Condition": "{% $trigger.current.JobStatus = 'Complete' %}",
      "Next": "DoSomething"
    }
  ],
  "Default": "Skip"
}
```

**`Pass`** — pure transform; no I/O. Use sparingly. Heavy use of Pass states with multi-line `Assign` JSONata is the cleanest signal that the platform is missing an action.

**`Succeed`/`Fail`** — terminal. End the workflow.

### Resource ARN format — `action:<name>` prefix is REQUIRED

ASL spec wants a Lambda ARN. The platform short-circuits this with a custom prefix:

| Wrong | Right |
|-------|-------|
| `"Resource": "http"` | `"Resource": "action:http"` |
| `"Resource": "graphql-query"` | `"Resource": "action:graphql-query"` |

Without the prefix, save fails with `SCHEMA_VALIDATION_FAILED: Value is not a valid resource ARN`.

---

## 7. JSONata expressions in this context

JSONata expressions are wrapped in `{% ... %}`. Anywhere a string value appears in `Arguments` or `Choices.Condition`, you can use a `{% %}` expression instead.

### Trigger payload reference: `$trigger`

The runtime exposes the trigger event as a top-level `$trigger`. Don't use `$states.input.triggerData.X` even though that's what the DTO type suggests.

| Path | Value |
|------|-------|
| `$trigger.current.<field>` | Post-state record fields |
| `$trigger.previous.<field>` | Pre-state for `Update` operations (often null for `Insert`) |
| `$trigger.operation` | `"INSERT"`, `"UPDATE"`, or `"DELETE"` |
| `$trigger.objectType` | The schema name |

### State result reference: by Assign-variable name

The platform auto-generates an `Assign` block for each Task on save, binding the state's result to a variable named `toCamelCase(stateName)`:

```typescript
// toCamelCase logic used by the platform to generate Assign variable names
function toCamelCase(input: string): string {
  const tokens = input.split(/[^a-zA-Z0-9]+/).filter(Boolean)
  const words = tokens.flatMap(token =>
    token.split(/(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])/).filter(Boolean),
  )
  if (words.length === 0) return ''
  return words
    .map((word, i) => (i === 0 ? word.toLowerCase() : word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()))
    .join('')
}
```

Examples:
- `FetchJobWithAllocation` → `fetchJobWithAllocation`
- `Echo Start Time` → `echoStartTime`
- `update-records-1` → `updateRecords1` (after stripping non-alnum)

Then in any downstream state, reference the result via:

```jsonata
{% $fetchJobWithAllocation.result.data.jobs.edges[0].node.UID %}
```

For `http`, drop the `.result.data` envelope: `{% $postToClearesult.body %}`, `{% $postToClearesult.statusCode %}`.

**Reserved names that cannot be produced:** `trigger`, `automationContext` (the platform refuses to bind these because they're root-level globals).

### Block expressions need parentheses

JSONata `;`-separated block expressions must be wrapped in parens — Step Functions' JSONata implementation rejects bare `expr1; expr2`:

```jsonata
{% ($accountId := $trigger.current.UID; $now := $now(); 'query { ... ' & $accountId & ' ...') %}
```

### `\'` escape is rejected — use double-quoted JSONata strings

Step Functions' JSONata rejects `\'` even though the public spec recognises it. Workaround: switch any string that contains a literal `'` to a double-quoted JSONata string. Inside `"..."` JSONata strings, `'` is literal (no escape needed).

**Wrong** (single-quoted JSONata, with backslash-escaped single quotes — fails):

```jsonata
'query { jobs(filter: \"AccountId == \\\'\'' & $accountId & '\'\\\"\")") { ... } }'
```

**Right** (double-quoted JSONata, single quotes literal):

```jsonata
"query { jobs(filter: \"AccountId == '" & $accountId & "'\") { ... } }"
```

In JSON encoding, every `"` becomes `\"` and every `\` becomes `\\`. Build the JSONata source mentally first, then JSON-encode.

### Recognised JSONata escapes

`\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, `\uXXXX`. **Not** `\'` and not arbitrary `\<char>`.

### Trigger filter cannot reference `previous`

The `objectModified.config.filter` runs against the post-state record only. To detect "field X changed", do it in a Choice state at the start of the workflow:

```json
{
  "Type": "Choice",
  "Choices": [
    {
      "Condition": "{% $trigger.current.Start != $trigger.previous.Start or $trigger.current.End != $trigger.previous.End %}",
      "Next": "Continue"
    }
  ],
  "Default": "Skip"
}
```

This adds 1 node + 1 expression per checked field. A native field-change predicate in the trigger filter would eliminate the boilerplate; today it doesn't exist.

---

## 8. The pre-flight checklist

These 9 corrections are not in any DTO file. Apply ALL of them before every POST.

| # | Correction | Wrong → Right |
|---|------------|---------------|
| 1 | Resource needs `action:` prefix | `"Resource": "http"` → `"Resource": "action:http"` |
| 2 | Trigger payload is `$trigger`, not `$states.input.triggerData` | `$states.input.triggerData.current.UID` → `$trigger.current.UID` |
| 3 | State results addressed by Assign-variable name (auto-generated as `toCamelCase`) | `$states.context.FetchTemplates.X` → `$fetchTemplates.result.data.X` |
| 4 | Action responses are wrapped in `{result: {data, errors}}`; `http` is unwrapped | Use `.result.data.X` for normal actions, `.body` / `.statusCode` for `http` |
| 5 | JSONata `\'` escape rejected | Switch to double-quoted JSONata outer strings; `'` is then literal |
| 6 | JSONata block expressions need parens | `{% $x := y; expr %}` → `{% ($x := y; expr) %}` |
| 7 | API `status` defaults to `enabled` | Always set `"status": "disabled"` explicitly for new loads |
| 8 | Don't set `workflow.definition.QueryLanguage` | Service auto-injects |
| 9 | `trigger.config.filter` must be non-empty for `objectModified` | Use `"UID != null"` for "always" |

---

## 9. End-to-end workflow

### Step 1: Confirm tenant + auth

```bash
# Source a shim that exports AUTOMATION_SERVICE_URL and AUTOMATION_SERVICE_TOKEN
source ./load-env.sh

curl -s -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/" | jq -r '.[] | "\(.status)\t\(.name)"' | head
```

If that lists existing automations, you're authenticated.

### Step 2: Decide trigger and actions

- What change should fire this? → trigger object/operations/filter
- What needs to happen, in order? → list of states
- Any branching? → Choice states
- External API call? → `http`
- Multi-record updates? → `update-records[ids]` or `delete-records[ids]` (uniform updates only — see §11 for variants)

### Step 3: Write the JSON

Start from a working example in §10 ("Pattern templates"). Apply the §8 checklist as you go.

Save to `<project-root>/automations/<source-id>.json`. Use a `validation-` or `dev-` name prefix for safety.

### Step 4: Score the glue

Run a glue counter to catch over-engineered cases before loading. Reference scale in §11.

### Step 5: Load disabled

```bash
curl -X POST -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  -H "Content-Type: application/json" \
  --data @<file>.json \
  "$AUTOMATION_SERVICE_URL/automations/"
```

The response gives you `id`. Verify with:

```bash
curl -s -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/<urlencoded-name>" | jq '.status'
# expect "disabled"
```

### Step 6: Inspect in the platform UI

Open your tenant's platform UI, navigate to the Automations app, search for your name. Confirm:

- Visual graph renders correctly
- Property panels show the `Arguments`/`Condition` JSONata cleanly
- Field-picker autocomplete works for `query-record.fields[]`

### Step 7: Manually execute (optional)

Trigger a real change event matching your filter, OR call the manual-invoke endpoint:

```bash
curl -X POST -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"current": {...}, "previous": {...}}' \
  "$AUTOMATION_SERVICE_URL/automations/<name>/execute"
```

Read logs:

```bash
curl -s -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/logs?limit=20" | jq
```

### Step 8: Enable for production traffic (optional)

Only after the user has confirmed the side effects are intended:

```bash
curl -X POST -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/<name>/enable"
```

### Step 9: Cleanup (always, for experiments)

```bash
curl -X DELETE -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/<id-or-name>"
```

If you tracked ids in a `created-automations.json`, sweep them all in a loop.

---

## 10. Pattern templates

### Template A: External API mirror on field change

When a record's specific fields change, POST a payload to an external API.

```json
{
  "name": "validation-mirror-on-field-change",
  "description": "When a Job's Start or End changes, sync to external API.",
  "trigger": {
    "type": "objectModified",
    "config": { "objectType": "Jobs", "operations": ["Update"], "filter": "UID != null" }
  },
  "workflow": {
    "definition": {
      "StartAt": "CheckIfTimeChanged",
      "States": {
        "CheckIfTimeChanged": {
          "Type": "Choice",
          "Choices": [{
            "Condition": "{% $trigger.current.Start != $trigger.previous.Start or $trigger.current.End != $trigger.previous.End %}",
            "Next": "FetchJob"
          }],
          "Default": "NoChange"
        },
        "NoChange": { "Type": "Succeed" },
        "FetchJob": {
          "Type": "Task",
          "Resource": "action:query-record",
          "Arguments": {
            "objectType": "Jobs",
            "id": "{% $trigger.current.UID %}",
            "fields": ["UID", "Name", "Start", "End", "JobStatus"]
          },
          "Next": "PostToExternal"
        },
        "PostToExternal": {
          "Type": "Task",
          "Resource": "action:http",
          "Arguments": {
            "url": "https://api.example.com/jobs",
            "method": "POST",
            "headers": { "Content-Type": "application/json", "Authorization": "Bearer EXTERNAL_TOKEN" },
            "body": {
              "id": "{% $fetchJob.result.data.UID %}",
              "name": "{% $fetchJob.result.data.Name %}",
              "start": "{% $fetchJob.result.data.Start %}",
              "end": "{% $fetchJob.result.data.End %}"
            }
          },
          "End": true
        }
      }
    }
  },
  "status": "disabled"
}
```

### Template B: Cascade with bulk update

Trigger fires on record change → query related records → apply same fields to all.

```json
{
  "name": "validation-cascade-cancel",
  "description": "When an Account is discharged, cancel all of its open future jobs.",
  "trigger": {
    "type": "objectModified",
    "config": { "objectType": "Accounts", "operations": ["Update"], "filter": "Status == 'Discharge'" }
  },
  "workflow": {
    "definition": {
      "StartAt": "QueryFutureOpenJobs",
      "States": {
        "QueryFutureOpenJobs": {
          "Type": "Task",
          "Resource": "action:graphql-query",
          "Arguments": {
            "query": "{% ($accountId := $trigger.current.UID; $cutoff := $trigger.current.DischargeDate ? $trigger.current.DischargeDate : $now(); \"query { jobs(filter: \\\"JobStatus != 'Cancelled' AND JobStatus != 'Complete' AND AccountId == '\" & $accountId & \"' AND Start >= \" & $cutoff & \"\\\"\") { edges { node { UID } } } }\") %}",
            "variables": {}
          },
          "Next": "DecideWhetherToCancel"
        },
        "DecideWhetherToCancel": {
          "Type": "Choice",
          "Choices": [{
            "Condition": "{% $count($queryFutureOpenJobs.result.data.jobs.edges) = 0 %}",
            "Next": "Done"
          }],
          "Default": "CancelJobs"
        },
        "Done": { "Type": "Succeed" },
        "CancelJobs": {
          "Type": "Task",
          "Resource": "action:update-records",
          "Arguments": {
            "objectType": "Jobs",
            "ids": "{% $queryFutureOpenJobs.result.data.jobs.edges.node.UID %}",
            "fields": { "JobStatus": "Cancelled" }
          },
          "End": true
        }
      }
    }
  },
  "status": "disabled"
}
```

Note: the `ids` argument auto-flattens via JSONata semantics — `edges.node.UID` produces an array of UIDs from the array of edges.

### Template C: Invariant-maintenance with multi-rule Choice

When a record's flag changes, demote siblings and update parent.

```json
{
  "name": "validation-default-flag",
  "description": "When a Location is set Default, demote sibling Locations of the same Account and set Account.DefaultLocationId.",
  "trigger": {
    "type": "objectModified",
    "config": { "objectType": "Locations", "operations": ["Insert", "Update"], "filter": "AccountId != null" }
  },
  "workflow": {
    "definition": {
      "StartAt": "FetchAccount",
      "States": {
        "FetchAccount": {
          "Type": "Task",
          "Resource": "action:query-record",
          "Arguments": {
            "objectType": "Accounts",
            "id": "{% $trigger.current.AccountId %}",
            "fields": ["UID", "DefaultLocationId"]
          },
          "Next": "Branch"
        },
        "Branch": {
          "Type": "Choice",
          "Choices": [
            {
              "Condition": "{% $trigger.current.Default = true %}",
              "Next": "QueryOtherDefaults"
            },
            {
              "Condition": "{% $trigger.current.Default = false and $fetchAccount.result.data.DefaultLocationId = $trigger.current.UID %}",
              "Next": "ClearDefault"
            }
          ],
          "Default": "NoChange"
        },
        "NoChange": { "Type": "Succeed" },
        "QueryOtherDefaults": {
          "Type": "Task",
          "Resource": "action:graphql-query",
          "Arguments": {
            "query": "{% ($a := $trigger.current.AccountId; $u := $trigger.current.UID; \"query { locations(filter: \\\"AccountId == '\" & $a & \"' AND UID != '\" & $u & \"' AND Default == true\\\"\") { edges { node { UID } } } }\") %}",
            "variables": {}
          },
          "Next": "DemoteIfAny"
        },
        "DemoteIfAny": {
          "Type": "Choice",
          "Choices": [{
            "Condition": "{% $count($queryOtherDefaults.result.data.locations.edges) > 0 %}",
            "Next": "Demote"
          }],
          "Default": "Promote"
        },
        "Demote": {
          "Type": "Task",
          "Resource": "action:update-records",
          "Arguments": {
            "objectType": "Locations",
            "ids": "{% $queryOtherDefaults.result.data.locations.edges.node.UID %}",
            "fields": { "Default": false }
          },
          "Next": "Promote"
        },
        "Promote": {
          "Type": "Task",
          "Resource": "action:update-records",
          "Arguments": {
            "objectType": "Accounts",
            "ids": ["{% $trigger.current.AccountId %}"],
            "fields": { "DefaultLocationId": "{% $trigger.current.UID %}" }
          },
          "End": true
        },
        "ClearDefault": {
          "Type": "Task",
          "Resource": "action:update-records",
          "Arguments": {
            "objectType": "Accounts",
            "ids": ["{% $trigger.current.AccountId %}"],
            "fields": { "DefaultLocationId": null }
          },
          "End": true
        }
      }
    }
  },
  "status": "disabled"
}
```

`update-records` accepts `null` for nullable fields cleanly — confirmed by direct load.

---

## 11. Glue metric reference

A simple weighted score that catches over-engineered automations. Compute from the JSON:

```text
score = 1.0 × expression_count
      + 1.5 × pass_state_count
      + 0.5 × choice_rule_count
      + 2.0 × deepest_expression_nesting
      + (longest_expression_chars / 80)
```

| Tier | Score | Interpretation |
|------|-------|----------------|
| **Trivial** | < 5 | One trigger + one action, no branching. Floor for any non-empty automation. |
| **Light (low)** | 5–12 | Cascade with bulk `update-records[ids]` / `delete-records[ids]`. Platform's strongest pattern. |
| **Light** | 12–20 | Invariant maintenance with multi-branch Choice. |
| **Light (high)** | 20–30 | Field-change-driven mirror; nested hasMany construction. |
| **Heavy** | 30–50 | Multi-step transforms; several Pass states emulating helpers. |
| **Pathological** | 50+ or any score with timezone/recurrence math attempted in JSONata | Reject as not-fit-for-platform. Suggest a connected function instead. |

**Caveat:** the metric undermeasures Pathological cases. If the JSONata is computing something the original handler wasn't (because actual behaviour can't be expressed), the score doesn't show that. Always pair with a qualitative check.

---

## 12. Common 400/500 errors and fixes

### `trigger.config.filter should not be empty`
Set `filter` to `"UID != null"` (or any non-empty EQL).

### `workflow.definition should not be null or undefined`
You wrapped wrong. The shape is `workflow: { definition: { ...StateMachine... } }`, not `workflow: { ...StateMachine... }`.

### `Value is not a valid resource ARN at /States/.../Resource`
Add the `action:` prefix to that state's `Resource` field.

### `INVALID_JSONATA_EXPRESSION: Syntax error: ";"`
JSONata block expression isn't parenthesised. Wrap as `{% (expr1; expr2; expr3) %}`.

### `INVALID_JSONATA_EXPRESSION: Unsupported escape sequence: \'`
Replace single-quoted JSONata strings containing `\'` with double-quoted JSONata strings (literal `'` inside `"..."`).

### `each value in operations must be one of the following values: Insert, Update, Delete`
Capitalisation matters for `operations[]`. `INSERT` / `UPDATE` / `DELETE` and `insert` / `update` / `delete` will both fail.

### `objectType must be a string` on an `event`-typed trigger
The `event` trigger isn't implemented. Re-scope to `objectModified`, or inform the user this case is platform-blocked.

### `name must only contain letters, numbers, spaces, hyphens, underscores, periods, and tildes`
Self-explanatory. Strip any other characters (especially `/`, `:`, `@`).

### Unique-constraint violation on name
Each name is unique within tenant. Append a timestamp or sequence number, or DELETE the existing one first.

---

## 13. Hard gaps (cannot work around in JSONata)

These are documented to save you (and the user) time spent trying to express them:

1. **No config-variable mechanism in actions.** The same automation cannot be deployed across tenants with different API endpoints / tokens / integration-user IDs. Per-tenant authoring is required today. _Highest-leverage missing primitive._
2. **No loop-prevention.** Customers commonly skip events where `LastModifiedById == <integration-user>`. Without config-vars, can't reference the per-tenant integration user id.
3. **`query-record` doesn't follow hasMany.** Forces `graphql-query` for any related-record fetch.
4. **No `event` trigger** (see §4).
5. **No deferred / scheduled triggers.**
6. **No timezone-aware date math primitive.** JSONata's `$fromMillis`/`$toMillis` work in UTC only.
7. **No recurrence-pattern expansion** (e.g. weekly/annual availability templates).
8. **No upsert.** `update-records[ids]` requires the records to exist. Insert-if-missing needs a separate Choice → `create-record` branch.
9. **No request-header access.** Trigger payload is the only input; headers don't surface.

When a user asks for any of these: explain the gap, propose either (a) staying in a connected function, or (b) approximating with a known compromise.

---

## 14. Setting up your environment

When working against a tenant repeatedly, use the `sked` CLI to manage authentication:

```bash
# Authenticate with your tenant
sked auth login

# Export the token for use in API calls
export AUTOMATION_SERVICE_TOKEN=$(sked auth print-token)
export AUTOMATION_SERVICE_URL="https://api.skedulo.com"  # adjust per tenant
```

Re-run `sked auth login` when your token expires.

---

## 15. Cleanup

Always end an experiment by deleting your created automations. Track ids in a local `created-automations.json` as you go:

```json
[
  {"id": "abc-123", "name": "validation-foo", "created_at": "2026-04-30T..."},
  {"id": "def-456", "name": "validation-bar", "created_at": "2026-04-30T..."}
]
```

Sweep loop:

```bash
jq -r '.[].id' created-automations.json | while read id; do
  curl -X DELETE -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
    "$AUTOMATION_SERVICE_URL/automations/$id"
done
```

After cleanup, verify the tenant is back to a clean state:

```bash
curl -s -H "Authorization: Bearer $AUTOMATION_SERVICE_TOKEN" \
  "$AUTOMATION_SERVICE_URL/automations/" | jq -r '.[].name' | grep '^validation-' || echo "All swept."
```

---

## 16. References

- **Source of truth (when this skill is stale):**
  - Live `GET /automations/swagger/v3-json` on the target tenant — this always reflects the current API surface
- **In-product docs:** Skedulo developer docs (search "automations") — these can lag the API
- **Step Functions JSONata:** AWS docs at `docs.aws.amazon.com/step-functions/latest/dg/transforming-data.html` — but note the platform's implementation diverges (no `\'`, parens-required blocks)
- **Companion skill:** `connected-function-developer` — when an automation can't express the case and you need a serverless API instead

When in doubt, fetch the live OpenAPI spec from the tenant — that always wins over any cached doc.
