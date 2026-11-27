---
name: horizon-custom-action-developer
description: This skill enables Claude to define, edit, review, and deploy Skedulo Horizon custom actions — the buttons on list views and record pages that send a templated HTTP request (GraphQL mutation, connected function, query API, or any HTTP endpoint) for the selected records. Covers the HorizonCustomAction state-file schema, single / batch / bulk execution and the Jinjava bindings each mode provides, the confirmation and result dialogs, how list configs and record pages display actions, platform defaults, and the sked CLI surface. A wrong template silently sends empty values; a missing primary key hides the action.
---

# Skedulo Horizon Custom Actions

A **custom action** is a button on a Horizon list view or record page. When a user runs it on one or
more selected records, the platform renders the action's `request` template (URL, body, headers) for
those records and sends the HTTP request from the server. Typical targets are the GraphQL API (update
or delete records), a connected function, the query API, or an external endpoint.

Actions are managed with the `sked artifacts horizon-custom-action` CLI surface this plugin wraps, and
work on both Pulse and Salesforce-flavor tenants. Whether an action appears on a list or page is
decided by that page's `displayedActions` (see Showing the Action).

## Goal

Produce deploy-ready action artifacts: one valid `src/horizon-custom-actions/<objectName>-<name>.horizon-custom-action.json`
per action, whose request renders correctly for its execution mode, with confirmation and result
dialogs a user can understand, tracked in SPEC.md, and reviewed against `references/review-checklist.md`.

## Guardrails

Platform rules you can't discover by reading the workspace — violations are rejected at upsert, or
accepted and then fail on every run. This section is the single source for these rules; everything
else in the plugin points here.

- **Never author the platform defaults**: `activate-user`, `deactivate-user`, `send-invitation` on
  `Users`; `page-delete`, `page-duplicate` on `PageTemplate`. Every tenant ships them. To change one,
  create a new action with its own `name`.
- **`objectName` must be an existing Horizon resource** (`Jobs`, `Contacts`, a custom object's
  resource name such as `Event Queue`), or the upsert fails with `resource does not exist`. Without
  `objectName` the action is attached to no resource.
- **`fields` must mark a primary key**, normally `{"name": "UID", "isPrimaryKey": true}`. The upsert
  accepts a missing key, but every run then fails with "No primary key field found". If several
  fields are marked, only the first is used.
- **Bindings depend on `executionMode.type`.** `single` sends one request per record with `id`, `key`,
  `item` (also `value`, `data`); `bulk` sends one request for all records and `batch` one per window,
  both with `ids`, `keys`, `items` (also `values`, `data`). A binding from the other mode renders as
  an empty string — no error, just a broken request. `args` and `tenantId`, `userId`, `skeduloApi`,
  `skeduloQueryApi` / `skeduloUiApi`, `skeduloJwt` exist in every mode.
- **`single` needs `failureMode`** (`CONTINUE_ON_FAILURE` or `CANCEL_ON_FAILURE`), or the upsert is
  rejected. **`batch` needs `batchSize` ≥ 1** — `0` is accepted at upsert and fails every run.
- **`request.method` must be GET, POST, PUT, PATCH, or DELETE** (any case). Other values are accepted
  at upsert and fail at run time.
- **`ui.refreshEnabled` and `ui.runInBackground` are required booleans.** Older files that omit
  `runInBackground` are now rejected — add it when touching them.
- **Every dialog needs an `interface`:** `ui.setup` (`standard` needs `title`, `message`,
  `confirmationButton`), and `ui.success`, `ui.partialSuccess`, `ui.failure` (`standard` needs
  `title`, `message`). A `custom` interface needs `templateName` instead.
- **Send the token in a header**: `Authorization: Bearer {{ skeduloJwt }}`. Never put `skeduloJwt` in
  the URL — URLs are logged. The token is a short-lived (10-minute) user token, so the request runs
  with the clicking user's permissions. Send it only to Skedulo APIs or the tenant's connected
  functions; an external service gets its own credential (a config variable), never the user's token.
- **Success means HTTP 2xx.** GraphQL returns errors with status 200, so a failed mutation shows as
  success. Pass `bodyJson` through `successResultTemplate` and check `successResults[].data.errors` in
  the success dialog before claiming the change (see the example and `references/request-patterns.md`).
- **Get, upsert, and delete find an action by `objectName` + `name`.** Two files with the same pair
  overwrite each other. `get` writes `<objectName>-<name>.horizon-custom-action.json` and fills in
  `successResultTemplate`, `actionMetadata`, and `securityConfig` defaults — include them to
  round-trip cleanly.

The plugin's `PostToolUse` hook (`scripts/validate_custom_actions.py`) enforces the shape, enum,
interface, primary-key, `batchSize`, and platform-default rules above on every Write/Edit of a state
file. It warns (without blocking) on a missing `objectName`, a non-`UID` primary key, a binding that
doesn't match the execution mode, a Skedulo URL without the bearer header, `skeduloJwt` in a URL,
blank headers, a bulk or batch action without `limit`, and a file name that doesn't match
`<objectName>-<name>`.

---

## State File Shape

**File**: `src/horizon-custom-actions/<objectName>-<name>.horizon-custom-action.json`

```json
{
  "metadata": { "type": "HorizonCustomAction" },
  "name": "complete-jobs",
  "objectName": "Jobs",
  "label": "Complete",
  "description": "Mark the selected jobs complete.",
  "request": {
    "method": "POST",
    "url": "{{ skeduloApi }}/graphql/graphql",
    "body": "{\"query\":\"mutation completeJobs { schema { {% for item in items -%} _j{{loop.index}}: updateJobs(input: { UID: \\\"{{ item.UID }}\\\", JobStatus: \\\"Complete\\\" }) {%- endfor -%} }}\"}",
    "headers": {
      "Authorization": "Bearer {{ skeduloJwt }}",
      "Content-Type": "application/json"
    }
  },
  "executionMode": { "type": "bulk" },
  "limit": 50,
  "successResultTemplate": { "template": "{{ bodyJson | json_encode }}", "contentType": "APPLICATION_JSON" },
  "fields": [{ "name": "UID", "isPrimaryKey": true }],
  "ui": {
    "refreshEnabled": true,
    "runInBackground": false,
    "setup": { "interface": { "type": "standard", "title": "Complete jobs", "message": "Complete {{ record_count }} job(s)?", "confirmationButton": "Complete" } },
    "success": { "interface": { "type": "standard", "title": "Complete jobs", "message": "{% set r = successResults | first %}{% if r and r.data and r.data.errors %}Not completed: {{ r.data.errors[0].message }}{% else %}{{ successCount }} job(s) completed.{% endif %}" } },
    "partialSuccess": { "interface": { "type": "standard", "title": "Some jobs not completed", "message": "{{ failureCount }} of {{ recordCount }} failed." } },
    "failure": { "interface": { "type": "standard", "title": "Jobs not completed", "message": "No jobs were completed." } }
  }
}
```

| Key | Required | Notes |
|---|---|---|
| `metadata.type` | Yes | Exactly `"HorizonCustomAction"` |
| `name` | Yes | kebab-case by convention; unique per `objectName` |
| `objectName` | In practice | Horizon resource the action belongs to |
| `label` | Yes | Button text |
| `description` | No | |
| `request` | Yes | `method`, `url` (template), optional `body` (template string) and `headers` (template values). The method is not templated |
| `executionMode` | Yes | `{"type": "single", "failureMode": ...}`, `{"type": "batch", "batchSize": n}`, or `{"type": "bulk"}` |
| `fields` | In practice | Record fields sent to the action; exactly one primary key |
| `limit` | No | Max records per run; `0` or missing means no limit |
| `ui` | Yes | `refreshEnabled`, `runInBackground`, `setup`, `success`, `partialSuccess`, `failure` |
| `successResultTemplate` | No | `{template, contentType: TEXT_PLAIN \| APPLICATION_JSON}` — renders the response with `headers`, `body`, `bodyJson` |
| `securityConfig` | No | `{permissions: [...], featureFlags: [...]}` — users without them don't see the action |
| `actionMetadata` | No | Discovery metadata: `{objects: [...], context: [...], enabled, order}` — places the action in contexts such as the scheduling experience (see Showing the Action) |

## Templates

Two template engines are involved:

- **Request (server, Jinjava):** `request.url`, `request.body`, and header values. An undefined
  binding renders empty; a syntax error fails the request. Build JSON bodies with `{% set %}` and
  `| json_encode` (as the platform's own `activate-user` does) rather than hand-escaping when values
  can contain quotes.
- **Dialogs (browser, Nunjucks):** `ui.*.interface` titles and messages. Setup dialogs see `action`,
  `values`, `args`, `record_count`, `resource_uid`, `selected_data_uids`; result dialogs see
  `results`, `recordCount` / `record_count`, `successCount`, `failureCount`, `successResults`,
  `failureResults`.

Request patterns for GraphQL, connected functions, the query API, and external calls are in
`references/request-patterns.md`.

## Showing the Action

List views and record pages show an action when its `objectName` matches the resource, its primary
key matches the resource's, and the user passes its `securityConfig`. The page's `displayedActions`
then decides:

| `displayedActions` | Result |
|---|---|
| `showActions: false` | No actions at all |
| `showActions: true`, `displayedActions: []` | Every action on the resource |
| `showActions: true`, `displayedActions: ["complete-jobs", ...]` | Only the named actions, in that order |

- **List views:** set it in the list config (see the `horizon-list-config` plugin).
- **Record pages:** the page template builds the same object and passes it to the actions component:
  `{% set displayedActions = {showActions: true, displayedActions: ['complete-jobs']} %}` then
  `displayed-actions={{ displayedActions | dump }}`. A bare array is ignored and every action shows.
- **Discovery metadata (newer path):** `displayedActions` and `resourceName` are deprecated on the
  actions component in favour of `actionDiscoveryMetadata`. An action opts in through its own
  `actionMetadata`:

  ```json
  "actionMetadata": {
    "objects": ["Jobs"],
    "context": ["skedulo-core/pulse-scheduling-experience/context_panel"],
    "enabled": true,
    "order": 10
  }
  ```

  Contexts seen in use: `skedulo-core/pulse-scheduling-experience`, `.../work_list`, `.../swimlane`,
  `.../context_panel`. Use it when the action must appear in the scheduling experience.

Adding a new action to a resource whose list shows `[]` makes it appear on that list straight away.

## CLI Surface

```bash
sked artifacts horizon-custom-action list   -a <alias> --json                                    # {"result": [full action objects]}
sked artifacts horizon-custom-action get    -a <alias> --name <NAME> --objectName <OBJ> -o <dir>  # writes <OBJ>-<NAME>.horizon-custom-action.json
sked artifacts horizon-custom-action upsert -a <alias> -f <state-file> -w 900                    # create or update by objectName + name
sked artifacts horizon-custom-action delete -a <alias> --name <NAME> --objectName <OBJ>
```

- `-a <alias>` is the tenant alias — always require it explicitly on the interactive path. On the
  headless path, where `SKED_CLI_API_TOKEN` binds the tenant, omit it (see `references/tenant-auth.md`).
- `create` and `update` are deprecated; use `upsert`.
- Deploy commands, the production packaging gate, and the error table live in `commands/deploy.md`.

## Workspace Layout (in the consuming project)

```text
<project>/                                   # CX project root = sked package root
├── skeduloPackage.json
├── SPEC.md                                  # action spec, progress tracking
└── src/
    ├── horizon-custom-actions/
    │   ├── Jobs-complete-jobs.horizon-custom-action.json
    │   └── Event Queue-event-queue-retry.horizon-custom-action.json
    └── horizon-list-configs/                # lists that display the actions
```

## Authoring Workflow

1. **Plan** each action in SPEC.md: resource, label, who may run it, target endpoint, execution mode,
   and which list or page displays it.
2. **Confirm** the resource and every field or mutation the request uses with the `graphql-schema` MCP.
3. **Author** one state file per action, starting from a pattern in `references/request-patterns.md`.
4. **Review** against `references/review-checklist.md` (inline in the build agent, or
   `/horizon-custom-action:review`).
5. **Deploy** explicitly via `/horizon-custom-action:deploy --alias <alias>`, add the name to the
   list config or page, then run the action on a test record.
