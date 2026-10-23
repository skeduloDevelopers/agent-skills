# Tenant authentication — alias-or-token resolution

Convention for any command or agent that runs a `sked` CLI call against a tenant. It works in two
environments with one resolution order, so the same flow behaves identically on a developer's
machine (interactive login) and inside the headless Skedulo Dev Agent sandbox (per-repo API token).

## Resolution order (highest priority first)

1. Explicit **`--alias <name>`** on the command → **interactive/local path**. Always wins over an ambient token.
2. **`SKED_CLI_API_TOKEN`** env var → **headless path** (a per-repo API token provided to the automated Dev Agent sandbox). This is the *selection/priority* signal; the sandbox re-exports its value to `SKEDULO_API_TOKEN`, which is what the CLI actually consumes.
3. **`SKEDULO_API_TOKEN`** env var → legacy headless fallback.

## Interactive path (alias present)

- Verify the alias is authenticated and not expired:

```bash
sked tenant list 2>&1 | grep -E "^[[:space:]]*<alias>[[:space:]]+" \
  || { echo "ERROR: alias <alias> not found in 'sked tenant list' - run 'sked tenant login --alias <alias>' first" >&2; exit 1; }
```

- If the alias's "Token Expired?" column shows `yes`, stop and tell the user to run `sked tenant login --alias <alias>`.
- Pass **`-a <alias>`** on every subsequent `sked` command.

## Headless path (token present, no alias)

- The token is **tenant-scoped** — it binds the tenant. Do **NOT** pass `-a`.
- Verify auth before running anything else:

```bash
sked tenant display --json   # must exit 0; proves the CLI is authenticated against the intended tenant (whoami)
```

- **Fail-fast:** if `sked tenant display` fails (non-zero exit), STOP with a clear error. Never continue in an unauthenticated state.
- The token is consumed by the CLI via the `SKEDULO_API_TOKEN` env var (the Dev Agent already exports it from the resolved source).

## No auth (neither alias nor token)

- **Interactive session** → ask the user for an alias (`AskUserQuestion`), then use the interactive path.
- **Non-interactive / agent session** → fail-fast; or, for verify-only steps (e.g. a dry-run), degrade gracefully and log `dry-run skipped: no tenant auth`.

## Hygiene

- **NEVER** log, echo, or print the token value.
- The verification gate is `sked tenant display` (whoami — headless) or `sked tenant list` (alias) — do not assume auth without running it.

## Live GraphQL introspection (referential check)

To confirm an object or field actually **exists on the tenant** (e.g. a Lookup's `targetObjectName`,
or a field a filter/template references), introspect the tenant's GraphQL schema. This catches
referential errors that neither the local schema validator nor `sked package deploy local --dryRun`
reliably catch (the dry-run passes a dangling Lookup target — introspection does not).

**Primary path — the wired `graphql-schema` MCP** (`mcp__graphql-schema__*`): use it when it resolves
the type against the connected tenant. It needs no `apiBasePath` plumbing, so it is the reliable path
**headless**. Fall back to a live introspection POST only when the MCP can't resolve the type (e.g.
custom types it doesn't cover) AND an `apiBasePath` is available:

```bash
# endpoint = <apiBasePath>/graphql/graphql ; auth = the resolved alias/token bearer
curl -s -X POST "$API_BASE_PATH/graphql/graphql" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"query{ t:__type(name:\"Clubs\"){ name } }"}'
# → {"data":{"t":{"name":"Clubs"}}} when it exists; {"data":{"t":null}} when it does NOT
```

- `__type(name:"<Type>")` returns the type when it exists, `null` when it does not. Verify fields with
  `__type(name:"<Type>"){ fields { name } }`.
- **Resolving `apiBasePath` for the POST fallback:** interactive — from the alias's stored credentials
  (`~/.config/sked/config.json` → `users.<alias>.apiBasePath` / `.accessToken`). Headless — only if the
  sandbox provides a tenant API base (e.g. `SKEDULO_API_SERVER`); if it does **not**, the raw POST is
  not available headlessly — rely on the `graphql-schema` MCP (primary path) instead. Never print the token.
- **Lookup-target existence rule:** a Lookup `targetObjectName` is valid when it is (a) a standard
  object, (b) a custom object being created in the same package (`src/object-model/custom-objects/`),
  or (c) already present on the tenant (`__type` non-null). If none hold → the reference is dangling.
