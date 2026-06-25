# Skedulo Pulse Webhooks

Author, edit, review, and deploy Skedulo Pulse Webhooks — the two event-automation cases Triggered Actions cannot cover: scheduled (cron) execution and inbound SMS.

## Use this skill when

- Firing an automation on a cron schedule (`scheduled`)
- Handling an inbound SMS sent to a Skedulo-provisioned number (`inbound_sms`)
- Wiring an HTTP POST to a Connected Function or external service on schedule or SMS
- Deploying a webhook via `sked artifacts webhook`

## Key rules

- Scope is `scheduled` and `inbound_sms` only — object-change automations are Triggered Actions
- A webhook's only side effect is the HTTP POST: it cannot send SMS or run a post-fire GraphQL query
- HTTPS only; config-variable templating is allowed on `url` and `headers` only
- `inbound_sms` needs a Skedulo-provisioned Twilio number (request it via your Customer Success Manager)
- `repeatableId` is server-assigned and read-only

## Example

```json
{
  "metadata": { "type": "Webhook" },
  "name": "Nightly sync",
  "webhook": { "type": "scheduled", "cron": "0 2 * * *", "url": "https://example.com/sync" }
}
```
