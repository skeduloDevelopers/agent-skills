# UserRole Review Checklist

The single checklist for reviewing user-role state files — used by the build agent's review
phase and `/user-role:review`. Each item enforces a rule stated once in SKILL.md (see its
Guardrails for the rationale).

## Schema

- JSON parses; `metadata.type` is exactly `"UserRole"`
- Exactly the five keys — `metadata`, `name`, `description`, `custom`, `permissionPatterns` —
  all present and non-empty (`permissionPatterns` is a non-empty array of strings)
- `custom` is the JSON boolean `true` on every authored role

## Naming & Filename

- Filename is exactly `<name>.user-role.json`, matching the `name` value including case
  (round-trips with `sked artifacts user-role get`)
- `name` has no leading/trailing whitespace; Title Case and descriptive by convention

## Default-Role Safety

- No authored file targets a platform default name or sets `custom: false` (retrieved
  reference files are exempt — confirm SPEC.md marks them reference-only)
- No custom role grants the full-admin `skedulo.tenant.*` wildcard

## Permissions

- Every key exists in `references/permission-keys.md` or was copied verbatim from a retrieved
  default — no invented granular view keys on wildcard-only groups
- Feature-flag-gated keys are noted in SPEC.md with their required flag (they only deploy on
  tenants with the flag enabled)
- Least-privilege sanity: specific keys preferred over group wildcards; no `.modify`/write
  keys on a role described as read-only; `web.access` present for human web roles and omitted
  for token-only roles

## Budget

- Total custom roles stay within the 20-per-tenant limit
