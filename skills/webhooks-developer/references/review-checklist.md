# Webhook Review Checklist

Structural rules — `metadata.type`, HTTPS/config-var URL, type scope, 5-field cron,
filename↔`name` match, `repeatableId`/`enabled` strays, flat shape — are owned by
`scripts/validate_webhooks.py`. Run it; don't re-derive its checks by eye.

What the script can't judge:

- **Type choice is right.** A Webhook of type `scheduled` or `inbound_sms` must answer a need a
  Triggered Action cannot (see `ta-vs-webhook.md`). Object-change work authored here as `graphql`
  is a routing mistake, not a schema one.
- **Cron means what the user asked.** The expression fires on the platform's UTC clock — "9am
  daily" for a tenant in another timezone is not `0 9 * * *`. No sub-minute schedules exist.
- **Config variables exist in the target tenant.** Every `{{ VAR }}` referenced in `url` or
  `headers` must be registered before deploy — an unregistered var fails the webhook at fire time,
  not at upsert.
- **`inbound_sms` prerequisite is tracked.** The Skedulo-provisioned Twilio number cannot be
  self-provisioned; the artifact upserts fine and stays silent until the number is provisioned and
  routed, then fires normally. SPEC.md should record whether it's in place.
- **The receiving endpoint is idempotent.** The platform retries up to 6 times, so the same POST
  can land more than once. Do **not** key dedup off `Skedulo-Webhook-Id` — it is the webhook's
  configuration UID and is identical on every fire, and a `scheduled` body is always `{}`, so that
  header plus the payload is the same value forever and a conforming receiver would accept the
  first fire and silently drop every later one. `Skedulo-Request-Id` is the per-request identifier
  (documented as "an ID that represents the specific request"), so it is the only candidate key —
  but the docs do not state whether it is preserved across the retries of a single fire, which is
  exactly the property an idempotency key needs. Confirm that with Skedulo before relying on it;
  until then treat the handler as needing effect-level idempotency of its own.
- **A `scheduled` endpoint expects no record context** — the POST body is always `{}`.
- **Sandbox and production are provisioned separately.** A webhook proven in sandbox can be silent
  in production if the prod number or API user is missing.
- **SPEC.md matches reality** — every completed feature has a corresponding state file.
