# Skedulo Automations Developer

Create, edit, and deploy Skedulo Pulse automations — AWS Step Functions state machines authored as JSON and saved through the Automations REST API.

## Use this skill when

- Writing a new automation state machine in JSON
- Editing an existing automation
- Debugging a `400` or `500` from `POST /automations/`
- Translating a webhook, triggered action, or connected function into an automation
- Scoping what the automation platform can do during a discovery call

## Key rules

- Each automation persists as `{ name, description, trigger, workflow, status }`
- Triggers fire on platform change events (`objectModified`)
- Wrap JSONata expressions in `{% ... %}`; the platform auto-injects `QueryLanguage: "JSONata"` and a per-Task `Assign` block — do not set them yourself
- Apply the documented schema corrections — the raw Step Functions schema will not load as-is
- Authenticate every request with `Authorization: Bearer <jwt>` (`sked auth print-token`)
- For server-side code, use `connected-function-developer` instead

## Example

```json
{
  "name": "Notify on job completion",
  "trigger": { "type": "objectModified", "object": "Jobs" },
  "workflow": {
    "StartAt": "Notify",
    "States": { "Notify": { "Type": "Task", "End": true } }
  },
  "status": "active"
}
```
