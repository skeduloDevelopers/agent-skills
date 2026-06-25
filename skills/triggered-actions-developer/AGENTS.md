# Skedulo Pulse Triggered Actions

Author, edit, review, and deploy Skedulo Pulse Triggered Actions — event-driven automations that fire on object modifications, platform events, and deferred timers.

## Use this skill when

- Automating on object INSERT / UPDATE / DELETE, platform events, or deferred timers
- Wiring a `call_url` (HTTP POST with a GraphQL payload) or `send_sms` action
- Writing EQL filters with `Current.` / `Previous.` prefixes
- Templating SMS or headers with Mustache helpers, config vars, or `{{ SKEDULO_USER_TOKEN }}`
- Debugging a rejected `sked artifacts triggered-action upsert`

## Key rules

- Two trigger types (`object_modified`, `event`); two action types (`call_url`, `send_sms`)
- HTTPS only — a non-HTTPS `action.url` is rejected (use a tunnel for local dev)
- `object_modified` requires change-event tracking enabled on the object
- For cron schedules or inbound SMS, use `webhooks-developer` instead
- `SKEDULO_USER_TOKEN` is a live bearer credential — only forward it to trusted first-party functions

## Example

```json
{
  "trigger": {
    "type": "object_modified",
    "schemaName": "Jobs",
    "filter": "Current.Status == 'Complete' && Previous.Status != 'Complete'"
  },
  "action": { "type": "call_url", "url": "https://example.com/on-complete" }
}
```
