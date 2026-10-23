# Triggered Action vs Webhook — decision matrix

The canonical decision matrix for choosing between the two Pulse event-automation artifacts.

Both are implemented on the same platform machinery — a Webhook is a specialised
flavour of Triggered Action and shares the `/triggered_actions/logs` surface — but they are
configured against different APIs (`/triggered_actions` vs `/webhooks`), different `sked` CLI
artifacts, and different state-file shapes.

## The rule

- **Object INSERT / UPDATE / DELETE reactions → Triggered Action** (this plugin,
  `object_modified` trigger).
- **Cron schedules and inbound SMS → Webhook** (the `webhooks` plugin, `scheduled` /
  `inbound_sms` types) — the two things a Triggered Action cannot do.

## Capability matrix

| Capability                                                     | Triggered Action | Webhook |
| -------------------------------------------------------------- | ---------------- | ------- |
| Fire on object INSERT / UPDATE / DELETE                        | Yes              | Yes (`graphql` type — but see note below) |
| Include previous-values payload                                | Yes              | Yes     |
| Retrieve extra data via GraphQL query after the trigger fires  | Yes              | No — TA-only |
| Send an SMS as the action                                      | Yes              | No — TA-only |
| Fire after a time offset (deferred)                            | Yes              | Yes     |
| Fire on a cron schedule                                        | No               | Yes — webhook-only |
| Fire on inbound SMS                                            | No               | Yes — webhook-only |

## The `graphql` / `graphql_deferred` webhook types

The platform technically supports `graphql` and `graphql_deferred` webhook types that fire on
object changes. They overlap entirely with `object_modified` Triggered Actions while lacking the
TA-only capabilities (GraphQL query after fire, `send_sms` actions), so **object-change work
belongs in this plugin** — author it as a Triggered Action, never as a `graphql` webhook.

If the use case is not cron-based and not inbound-SMS-based, it is a Triggered Action.
