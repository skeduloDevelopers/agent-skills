# Connected Function Review Checklist

The single checklist for reviewing connected functions — used by the build agent's review phase
and `/connected-function:review`. These are the domain-specific platform rules; general code
quality (types, error handling, security hygiene) is assumed, not itemised.

## sked.proj.json

- `description` is ≤ 256 characters — deploy throws a `ValidationException` otherwise. Verify:

  ```bash
  jq -r '.description // ""' sked.proj.json | tr -d '\n' | wc -m
  ```

- Every config var read in code via `configVarClient.get(...)` is declared in
  `settings.configVars` (name, configType, description) — an undeclared var is silently
  `undefined` at runtime.

## Configuration Access

- Config vars are read via `context.configVarClient.get(key)` on an `ExecutionContext` — never
  `process.env` or `dotenv` (locally, `sked function dev` injects `.env` values AS config vars).

## Dependencies

- `package.json` `resolutions` pins `@dabh/diagnostics` to exactly `2.0.3` — not `^2.0.3` — and
  the lockfile reflects the pin. A green production `yarn compile` does not prove this; the
  failure only surfaces in default/dev bundles.

## EQL Filters

- Datetime comparisons (`Instant`/`Date`/`Local Date`/`Local Time` fields — e.g. `Start`, `End`,
  `CreatedDate`, any `*Date`/`*Time` field) use an unquoted literal
  (`Start > 2026-07-04T10:34:04.245Z`), never a quoted string — quoting silently 400s at runtime
  with `Expected type Instant but got String`, invisible under a try/catch.
- Tests for filter-building code assert the actual string passed to `withFilter(...)`, not just
  that `execute` resolved.

## Triggered Actions (if applicable)

- Each triggered-action manifest's URL matches a real route in the function
  (`POST /triggered-action/*` path and method agree between the `*.triggered-action.json`
  manifest and `routes.ts`) — a mismatch deploys fine and never fires.
