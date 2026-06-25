---
name: webhooks-developer
description: This skill enables Claude to author, edit, review, and deploy Skedulo Pulse Webhooks — the two event-automation cases that Triggered Actions cannot cover: scheduled (cron) execution and inbound SMS handling. Covers the canonical Webhook state-file shape (metadata / name / webhook), the 2 in-scope webhook types (`scheduled`, `inbound_sms`), cron expression syntax, inbound-SMS prerequisites (a Skedulo-provisioned Twilio number), HTTPS-only URLs, configuration-variable templating (allowed on `url` and `headers` only), the server-assigned read-only `repeatableId`, the headers Skedulo sets on outgoing requests, retries/timeouts, the shared triggered-actions log surface, and the platform rules that cause `sked artifacts webhook upsert` to reject otherwise-valid-looking JSON. For object INSERT/UPDATE/DELETE automations, use the triggered-actions plugin instead.
---
# Skedulo Pulse Webhooks Skill

## What is a Webhook in Pulse?

A Webhook is a server-side automation that makes an **HTTP POST to an HTTPS endpoint** when an event occurs in the tenant. Under the hood it is implemented as a specialised flavour of Triggered Action and shares the same log surface — but it is configured against a different API (`/webhooks`) and a different `sked` CLI artifact (`sked artifacts webhook`), and its state-file shape is different (flatter — there is no `trigger` / `action` split).

This plugin scopes Webhooks to the **two things a Triggered Action cannot do**:

- **`scheduled`** — fire on a **cron schedule** (every N minutes, daily at a time, etc.), independent of any data change.
- **`inbound_sms`** — fire when a **customer/resource sends an SMS** to a Skedulo-provisioned number.

Both deliver an HTTP POST to a URL you control — typically a Connected Function (Pulse) or an external service that does the real work. The Webhook is just the wiring that decides *when* to call it.

## Webhooks vs Triggered Actions (when to use which)

Default to **Triggered Actions** for all event-driven work. Reach for a **Webhook** ONLY when one of these two features is required:

| Feature                                                       | Triggered Action | Webhook            |
| ------------------------------------------------------------- | ---------------- | ------------------ |
| Fire on object INSERT / UPDATE / DELETE                       | ✅               | ✅ (`graphql`)     |
| Include previous-values payload                               | ✅               | ✅                 |
| Retrieve extra data via GraphQL query after the trigger fires | ✅               | ❌                 |
| Send an SMS **as the action**                                 | ✅               | ❌                 |
| Fire after a time offset (deferred)                           | ✅               | ✅                 |
| Fire on a **cron schedule**                                   | ❌               | ✅ — webhook-only |
| Fire on **inbound SMS**                                       | ❌               | ✅ — webhook-only |

If your use case is **not** cron-based and **not** inbound-SMS-based, it is a Triggered Action — use the `triggered-actions` plugin. This plugin deliberately covers only the two webhook-exclusive types (`scheduled`, `inbound_sms`). The platform also supports `graphql` and `graphql_deferred` webhook types for object changes, but those overlap with Triggered Actions and are out of scope here — author them as Triggered Actions instead.

> A Webhook **cannot send an SMS** and **cannot run a GraphQL query after firing**. Both are Triggered-Action-only. A Webhook's only side effect is the HTTP POST.

## Authentication & Prerequisites

Webhooks require:

- **API access token** in the `Authorization: Bearer <token>` header for every `/webhooks` API call. Tokens are minted in Pulse Web → Settings → API Tokens. The `sked` CLI handles this automatically once you have run `sked tenant login --alias <alias>` — the alias is your shorthand for the tenant + stored token.
- **HTTPS only.** Skedulo refuses non-HTTPS URLs. There is no `http://` exception even for localhost / dev — use ngrok or a similar tunnel for local testing.
- **Skedulo for Salesforce tenants need an API user** configured for the team, so the platform can act against the tenant on the webhook's behalf. Configure via Pulse Web → Settings → API user, per environment (sandbox + production).
- **`inbound_sms` requires a Skedulo-provisioned phone number.** Skedulo purchases a number through Twilio and pre-configures it to route inbound messages to your tenant. **You cannot self-provision this** — contact your Skedulo Customer Success Manager to request an inbound SMS number before an `inbound_sms` webhook will receive anything. The webhook artifact upserts fine without the number, but it never fires until the number is wired up.

## CLI Surface

```bash
# List existing webhooks in a tenant
sked artifacts webhook list -a <alias>

# Pull a webhook's state file into the local workspace
sked artifacts webhook get -a <alias> --name <WebhookName> -o <outputdir>

# Create OR update from a state file (deploys the local file to the tenant)
sked artifacts webhook upsert -a <alias> -f <state-file>

# Delete a webhook from the tenant by name
sked artifacts webhook delete -a <alias> --name <WebhookName>
```

All write commands (`upsert`, `delete`, the deprecated `create` / `update`) accept `-w <seconds>` (default `900`) to control the max wait before the CLI gives up on a slow tenant.

> Note: `create` and `update` are deprecated subcommands kept for backward compat — always use `upsert`, which handles both cases idempotently by `name`.

## Workspace Layout

```text
<your-project>/
├── SPEC.md                                    # spec, feature checklist
└── src/
    └── webhooks/
        ├── NightlyJobSweep.webhook.json
        └── InboundSmsRouter.webhook.json
```

Each Webhook is a single JSON file at `src/webhooks/<WebhookName>.webhook.json`. The filename's `<WebhookName>` MUST match the `name` field inside the JSON exactly — `sked artifacts webhook get` emits files in this convention, so authored files round-trip cleanly with retrieve.

No parent / child relationship exists between webhooks — each is independent, and deploy order does not matter.

## Canonical State File Shape

```json
{
  "metadata": { "type": "Webhook" },
  "name": "NightlyJobSweep",
  "webhook": {
    "url": "https://example.com/hook",
    "headers": {},
    "cron": "0 2 * * *",
    "type": "scheduled"
  }
}
```

### Top-level keys

| Key             | Required | Notes                                                                                                                          |
| --------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `metadata.type` | ✅       | Must be the literal string `"Webhook"`.                                                                                        |
| `name`          | ✅       | PascalCase string. Must match the filename's `<WebhookName>` portion. Uniqueness is enforced by the tenant.                     |
| `webhook`       | ✅       | The webhook config block. See per-type shapes below.                                                                           |

> There is **no `enabled` flag** and **no top-level `description`** on a Webhook (unlike a Triggered Action). To pause a webhook you delete it (or repoint its `url`). Keep human context in `SPEC.md`, not the artifact.

### `webhook` block keys

| Key            | Required | Applies to            | Notes                                                                                                                      |
| -------------- | -------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `type`         | ✅       | all                   | `"scheduled"` or `"inbound_sms"` (this plugin's scope).                                                                     |
| `url`          | ✅       | all                   | **MUST be HTTPS.** Supports `{{ CONFIG_VAR }}` templates.                                                                   |
| `headers`      | ⚠️ Opt. | all                   | Map of string → string. Supports `{{ CONFIG_VAR }}` templates. Defaults to `{}`.                                           |
| `cron`         | ✅       | `scheduled` only      | A 5-field cron expression — see Cron Syntax below.                                                                         |
| `repeatableId` | ❌       | `scheduled` (on read) | **Server-assigned, read-only.** Appears in `sked artifacts webhook get` output for scheduled webhooks. **Never author it** — omit it from files you write; the platform assigns it on upsert. |

## Webhook Types

### Type 1: `scheduled` (cron)

Fires on a fixed schedule using a cron expression. The POST body is an **empty object** `{}` — a scheduled webhook carries no record context; its only job is to ping your endpoint on a timer so the endpoint can do its own work (poll, sweep, reconcile, send a digest).

```json
{
  "metadata": { "type": "Webhook" },
  "name": "NightlyJobSweep",
  "webhook": {
    "url": "{{ JOB_SWEEP_URL }}",
    "headers": { "Authorization": "Bearer {{ JOB_SWEEP_TOKEN }}" },
    "cron": "0 2 * * *",
    "type": "scheduled"
  }
}
```

| Key     | Required | Notes                                                                |
| ------- | -------- | -------------------------------------------------------------------- |
| `type`  | ✅       | Literal `"scheduled"`.                                               |
| `url`   | ✅       | HTTPS endpoint to POST to. Supports config vars.                     |
| `cron`  | ✅       | 5-field cron expression (see below).                                 |
| `headers` | ⚠️ Opt. | Optional headers; supports config vars.                            |

#### Cron Syntax

A 5-field expression: `minute hour day-of-month month day-of-week`.

```text
 ┌───────────── minute (0 - 59)
 │ ┌───────────── hour (0 - 23)
 │ │ ┌───────────── day of the month (1 - 31)
 │ │ │ ┌───────────── month (1 - 12)
 │ │ │ │ ┌───────────── day of the week (0 - 6, Sunday = 0 or 7)
 │ │ │ │ │
 * * * * *
```

| Expression      | Fires                          |
| --------------- | ------------------------------ |
| `* * * * *`     | every minute                   |
| `*/5 * * * *`   | every 5 minutes                |
| `0 * * * *`     | top of every hour              |
| `0 2 * * *`     | daily at 02:00                 |
| `45 11 * * 5`   | every Friday at 11:45          |
| `0 9 1 * *`     | 09:00 on the 1st of each month |

> Cron fires on the platform's clock (UTC). Account for tenant timezone when you mean "9am local". The shortest practical interval is `* * * * *` (every minute) — there is no sub-minute schedule.

### Type 2: `inbound_sms`

Fires when an SMS is received on a Skedulo-provisioned inbound number. The incoming message payload (sender, body, etc.) is POSTed to your `url` so your endpoint can route it — e.g. update a job from a customer reply, or let a resource check in by texting a keyword.

```json
{
  "metadata": { "type": "Webhook" },
  "name": "InboundSmsRouter",
  "webhook": {
    "url": "{{ INBOUND_SMS_HANDLER_URL }}",
    "headers": {},
    "type": "inbound_sms"
  }
}
```

| Key       | Required | Notes                                                          |
| --------- | -------- | -------------------------------------------------------------- |
| `type`    | ✅       | Literal `"inbound_sms"`.                                       |
| `url`     | ✅       | HTTPS endpoint to POST the inbound message to. Supports config vars. |
| `headers` | ⚠️ Opt.  | Optional headers; supports config vars.                        |

`inbound_sms` webhooks have **no `cron` and no filter** — every inbound message on the provisioned number is delivered to the `url`; routing logic (which keyword, which job) lives in your endpoint. **Prerequisite: the Skedulo-provisioned Twilio number must be in place** (contact CSM) — without it the webhook never receives anything.

## Configuration Variables `{{ FOO_BAR }}`

Configuration variables are tenant-scoped values managed in Pulse Web → Settings → Configuration variables. Reference them with `{{ VAR_NAME }}` (keep the spaces inside the braces — they can be significant in older clients).

Supported locations on a Webhook:

- ✅ `webhook.url`
- ✅ `webhook.headers` (any header value)

Not supported anywhere else (there is no `query` / `template` on a Webhook). If a referenced config var is not found at fire time, the webhook **fails** — register every referenced var in the target tenant before deploy.

Using config vars for `url` (and any auth token in `headers`) is the recommended pattern: it keeps the same state file portable across sandbox and production, where only the config-var values differ.

## Headers Skedulo sets on outgoing requests

In addition to any `headers` you author, Skedulo always sends:

| Header                         | Value / Purpose                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------ |
| `User-Agent`                   | Literal `Skedulo-Webhook` — identifies the caller.                                               |
| `Skedulo-Webhook-Id`           | The webhook's configuration UID — **stable across every fire**. Key idempotency/dedup off this. |
| `Skedulo-Request-Id`           | Per-request ID (changes on every fire). Same value as `Skedulo-Triggeredactionlogid`.            |
| `Skedulo-Triggeredactionlogid` | Per-request log ID — webhooks carry this too, since they are implemented as triggered actions.   |

The receiving endpoint should parse the body defensively and not assume a particular `Content-Type`.

## Retries & timeouts

If no response is received within **25 seconds**, or the response status is not 2XX, the request is retried with exponential backoff, up to **6 attempts total** (initial + 5 retries):

| Retry # | Delay before retry |
| ------- | ------------------ |
| 1       | 5 seconds          |
| 2       | 30 seconds         |
| 3       | 5 minutes          |
| 4       | 30 minutes         |
| 5       | 3 hours            |

Because retries can replay the same call, the receiving endpoint must be **idempotent** — key dedup logic off `Skedulo-Webhook-Id` + the request payload.

## Logs & Debugging

Webhooks share the Triggered Action log surface — they are implemented as a flavour of Triggered Action.

```bash
# All logs (last 24h by default)
curl -X GET 'https://<api-base>/triggered_actions/logs' \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Webhooks only
curl -X GET 'https://<api-base>/triggered_actions/logs?isWebhook=true' \
  -H "Authorization: Bearer $AUTH_TOKEN"

# One specific webhook by its id (the Skedulo-Webhook-Id value)
curl -X GET 'https://<api-base>/triggered_actions/logs?sourceId=<WEBHOOK_ID>' \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

Each entry includes the URL called, the request body, the response status + headers, a retry counter, and an `attempts[]` array of prior failures with timestamps. A deferred/scheduled webhook can emit **multiple log entries per logical fire** (e.g. one for scheduling the task and one for the `call_url` step) — inspect all of them when debugging a "didn't fire" report.

The `<api-base>` matches the tenant's API base path (e.g. `https://api.au.skedulo.com`, `https://api.skedulo.com`) — see `sked tenant list`.

## Pulse Rules (the critical checklist)

These are the platform-enforced rules that cause `sked artifacts webhook upsert` to reject otherwise-valid-looking JSON, or cause silent runtime misbehaviour. The review-agent enforces all of them as Critical or High findings.

1. **`metadata.type` must be the literal `"Webhook"`** — not `"TriggeredAction"`. A copied Triggered Action file will deploy to the wrong artifact surface or be rejected.
2. **`webhook.url` must be HTTPS.** `http://` is rejected at upsert — including localhost. Use a tunnel (ngrok) for local testing.
3. **`webhook.type` must be `"scheduled"` or `"inbound_sms"`** for this plugin. `graphql` / `graphql_deferred` are object-change webhooks — author those as Triggered Actions instead.
4. **`scheduled` webhooks REQUIRE a valid 5-field `cron`.** A missing or malformed cron is rejected (or never fires). The body delivered is always empty `{}` — do not expect record context.
5. **`inbound_sms` webhooks REQUIRE a Skedulo-provisioned number** to actually fire. The artifact upserts without it, but stays silent. Flag "number provisioned with CSM?" in the deploy checklist.
6. **Never author `repeatableId`.** It is server-assigned and appears only on `get` for scheduled webhooks. Including a stale value from a different tenant can cause confusing upsert behaviour — strip it from retrieved files before re-deploying to a different tenant.
7. **No `enabled` flag exists** on a Webhook. Do not copy `enabled` over from a Triggered Action file — it is not part of the schema.
8. **Configuration variables substitute only in `webhook.url` and `webhook.headers`.** There is nowhere else on a Webhook they apply. A referenced-but-unregistered config var fails the webhook at fire time.
9. **The endpoint must be idempotent** — the platform retries up to 6 times on timeout/5xx, so the same POST can land more than once.
10. **Skedulo for Salesforce — provision the inbound number and register the API user per environment.** Sandbox and production are configured separately; a webhook that works in sandbox can be silent in production if the prod number/API user is missing.

## Common Patterns (the starter templates)

The plugin ships starter templates under `templates/`. Scaffold one via `/webhooks:build template:<name>`:

### `cron-callout` — POST on a cron schedule

A `scheduled` webhook that POSTs to a configurable URL (typically a Connected Function) on a cron timer. Use cases: nightly job sweep / reconciliation, hourly poll of an external system, a daily digest trigger, periodic cache warm-up. The empty `{}` body means the endpoint does the work; the webhook just wakes it on schedule.

### `inbound-sms-handler` — route incoming SMS

An `inbound_sms` webhook that forwards every inbound message to a configurable handler URL. Use cases: customer replies "C" to confirm an appointment → update the job; resource texts "START <jobno>" → check in. Requires a Skedulo-provisioned number (contact CSM).

Each template contains `<PLACEHOLDER>` strings the init-agent walks through with the user.

## Skedulo for Salesforce note

On Skedulo for Salesforce projects (Salesforce is the system of record, Pulse layers on top), Webhooks are still a Pulse artifact and work the same. Two things to remember:

1. **Provision the inbound SMS number and configure the Skedulo API user per environment** (sandbox AND production) before relying on an `inbound_sms` webhook. These are per-tenant Pulse settings, not code.
2. **Use config vars for `url`/`headers`** so the same state file deploys unchanged across environments — only the config-var values (the per-env Connected Function URL, auth token) differ.

## Authoring Workflow Recap

1. **Init session** — `/webhooks:build "<requirements>"` or `/webhooks:build template:<name>` or `/webhooks:build retrieve:<Name1>,<Name2> --alias <alias>`. Init agent scaffolds `SPEC.md` + `src/webhooks/`, then stops.
2. **Coding session** (new session) — `/webhooks:build`. Coding agent reads `SPEC.md`, generates the `.webhook.json` files, then auto-spawns the review agent via the SubagentStop hook.
3. **Review** — the review agent validates the Webhook state-file shape, cron syntax, HTTPS-only URLs, type scope, config-var usage, and the Pulse Rules above.
4. **Deploy** — `/webhooks:deploy --alias <alias>`. Explicit and non-autonomous. Per-file `sked artifacts webhook upsert -a <alias> -f <file>`.

The coding agent NEVER deploys autonomously. Deploy stays a deliberate, separate command.
