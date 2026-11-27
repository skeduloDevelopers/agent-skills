# TriggeredAction Review Checklist

The single checklist for reviewing triggered-action state files — used by the build agent's
review phase and `/triggered-actions:review`.

Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_triggered_actions.py" src/triggered-actions`
first — it deterministically covers the mechanically checkable subset (state-file shape, mandatory
filter, `Current.`/`Previous.` prefixes, `AND`/`OR`-only operators, HTTPS URLs, flat
`previousFields` under `action`, deferred-offset floor, event-filter form, filename/name match,
unresolved placeholders). The items below are what the script cannot verify.

## Schema references

- Every field in filter EQL, `action.query`, `previousFields`, and `send_sms` templates was
  confirmed against the GraphQL Schema MCP for the trigger `schemaName` (including dotted lookup
  paths like `Contact.Mobile`) — unverified fields reject at upsert or render empty at fire time
- `schemaName` is the registered Pulse type name (Skedulo for Salesforce: `__c` suffix dropped,
  object and every referenced field registered per environment)

## Filter semantics

- The filter constrains narrowly — not a bare `Operation == 'UPDATE'` against a high-traffic
  object; deferred TAs especially, since every matching record schedules a future fire at upsert
- `Current.` is only relied on for INSERT/UPDATE paths, `Previous.` only for UPDATE/DELETE —
  a filter needing `Previous.` never fires on INSERT

## Actions

- `action.type` matches what the tenant already has for this `name` (immutable on update —
  check with `sked artifacts triggered-action list -a <alias>` before upserting over an existing
  action)
- call_url targets handle the payload shape: INSERT has no `previous`, DELETE has no `data`
  (only auto-injected `previous.UID`), and batched changes arrive as an array
- `send_sms` templates are defensive about missing fields (they render as empty strings) and any
  DateTime field passed to `{{ formatDateTime }}` is always a valid datetime — an invalid value
  fails the whole send
- SMS volume was cost-checked — every fired `send_sms` is billed per message

## Templates & configuration

- Scaffolds from `templates/*.template.json` have every `<PLACEHOLDER>` replaced with a real
  value (the script flags leftovers)
- Every `{{ CONFIG_VAR }}` referenced in `action.url` / `action.headers` is documented in SPEC.md
  so the deployer can pre-verify it exists in the tenant

## Consistency

- Every completed automation in SPEC.md has a matching implemented `.triggered-action.json` file
- `enabled: false` files are deliberate (staging), not forgotten
