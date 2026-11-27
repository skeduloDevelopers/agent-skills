# HorizonCustomAction Review Checklist

The single checklist for reviewing custom-action state files — used by the build agent's review phase
and `/horizon-custom-action:review`. Each item enforces a rule stated once in SKILL.md (see its
Guardrails). Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_custom_actions.py" --workspace .`
from the project root first; its errors are Critical.

## Schema

- JSON parses; `metadata.type` is exactly `"HorizonCustomAction"`
- `name`, `label`, `request.method`, `request.url`, `executionMode`, and all four `ui` dialogs present
- `ui.refreshEnabled` and `ui.runInBackground` are JSON booleans
- `fields` has exactly one primary key, normally `UID`

## Identity

- Not one of the platform defaults (`activate-user`, `deactivate-user`, `send-invitation`,
  `page-delete`, `page-duplicate`)
- `objectName` is a real Horizon resource on the tenant or created in this project
- No two files share `objectName` + `name`; file name is `<objectName>-<name>.horizon-custom-action.json`

## Request

- Every binding exists in the execution mode: `id` / `item` only in single, `items` / `ids` only in bulk
  and batch (a `{% for item in items %}` loop is fine)
- Skedulo API calls send `Authorization: Bearer {{ skeduloJwt }}`; the token never appears in the URL
- JSON bodies are valid after rendering: GraphQL quotes escaped as `\\\"`, or built with `json_encode`
- Every GraphQL type, field, and mutation exists on the tenant
- Bulk and batch actions set `limit`; batch `batchSize` ≥ 1
- The request does only what the label says, for the clicking user's permissions

## Dialogs

- The setup message says what will happen and to how many records (`{{ record_count }}`)
- Success, partial-success, and failure messages tell the user what happened; GraphQL actions don't
  claim success they can't see (HTTP 200 carries errors)

## Visibility

- SPEC.md names the list config or record page that shows each action, and its `displayedActions`
  either lists the action `name` or is `[]` with `showActions: true` (shows every action)
- Actions meant for the scheduling experience carry `actionMetadata` with the right `objects` and
  `context`
- `securityConfig` permissions / feature flags, if set, match who should see the action
