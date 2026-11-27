# Skedulo Horizon Custom Actions

Define, edit, review, and deploy Horizon custom actions — list-view and record-page buttons that send a templated HTTP request for the selected records.

## Use this skill when

- Adding a bulk or per-record action button to a Horizon list view or record page
- Creating or editing a `*.horizon-custom-action.json` state file
- Calling a GraphQL mutation, connected function, or platform API from a button
- Deploying an action via `sked artifacts horizon-custom-action`

## Key rules

- `single` runs one request per record (`id`, `item`); `bulk` / `batch` run one request for many (`ids`, `items`) — a binding from the other mode renders empty
- `fields` needs a primary key (`UID`), or every run fails
- `single` needs `failureMode`; `batch` needs `batchSize` ≥ 1; `ui.refreshEnabled` and `ui.runInBackground` are required booleans
- Send `Authorization: Bearer {{ skeduloJwt }}` in a header, never in the URL
- Never author the platform defaults (`activate-user`, `deactivate-user`, `send-invitation`, `page-delete`, `page-duplicate`)
- A list shows an action when its `displayedActions` names it, or is `[]` with `showActions: true` (every action); `actionMetadata` places it in the scheduling experience

## Example

```json
{
  "metadata": { "type": "HorizonCustomAction" },
  "name": "delete-contacts",
  "objectName": "Contacts",
  "label": "Delete",
  "request": {
    "method": "DELETE",
    "url": "{{ skeduloQueryApi }}/query/v1/objects/{{ args.resourceId }}/{{ id }}",
    "headers": { "Authorization": "Bearer {{ skeduloJwt }}" }
  },
  "executionMode": { "type": "single", "failureMode": "CONTINUE_ON_FAILURE" },
  "fields": [{ "name": "UID", "isPrimaryKey": true }],
  "ui": {
    "refreshEnabled": true,
    "runInBackground": false,
    "setup": { "interface": { "type": "standard", "title": "Delete contacts", "message": "Delete {{ record_count }} contact(s)?", "confirmationButton": "Delete" } },
    "success": { "interface": { "type": "standard", "title": "Deleted", "message": "Contacts deleted." } },
    "partialSuccess": { "interface": { "type": "standard", "title": "Some not deleted", "message": "{{ failureCount }} failed." } },
    "failure": { "interface": { "type": "standard", "title": "Not deleted", "message": "No contacts were deleted." } }
  }
}
```
