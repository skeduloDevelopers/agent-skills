---
name: skedulo-cli
description: Use when running any Skedulo CLI (sked) command — deployments, artifact operations, package management, tenant switching. Prevents alias-loss bugs, enforces --help usage, and guides safe CLI patterns.
---

# Skedulo CLI

## Core Principle

Every tenant-scoped `sked` command MUST include `-a <alias>`. No alias in context? Ask the user. No exceptions.

## Rules

### 1. Always use `-a <alias>`

Every `sked` command that supports `-a` MUST include it.

1. Run `<command> --help` to confirm `-a` is supported
2. If supported, include `-a <alias>` — always
3. No alias in context? ASK the user — never guess, never omit

**Why:** Context compaction silently drops the alias, causing deploys to the wrong tenant.

**Red flags — STOP and check for alias:**

| Thought | Reality |
|---------|---------|
| "I already know which tenant" | Do you? Context may have compacted. Check. |
| "I'll add -a next time" | Add it NOW. There is no next time after a bad deploy. |
| "It's probably the default" | "Probably" has caused hours of debugging. Always specify. |
| "I just ran a command with -a" | That was then. Check you still have it. |
| "This is a quick one-off" | One-off commands hit tenants too. Use -a. |
| "This is a list command, not a deploy" | List commands are tenant-scoped too. Use -a. |
| "I checked --help earlier" | Earlier knowledge may be stale. Check again if unsure. |

### 2. Proactively use `--help`

Run `<command> --help` before guessing at flags. Works at every level: `sked --help`, `sked artifacts --help`, `sked artifacts function list --help`. Use it to confirm `-a` support (Rule 1) and discover flags like `--dryRun`, `--json`, `--verbose`.

### 3. Use `--json` for read-only inspection

Use `get --json` to inspect artifacts — NOT `get -o` which downloads files into the repo. Only use `-o` when you intend to modify the artifact.

### 4. Use `list` + `--json` for discovery

Query the platform instead of asking the user. Pattern: `sked artifacts <type> list --json -a <alias>`. Use it to get function URLs, introspect schemas, check webhooks, etc. Be self-sufficient.

**For field introspection:** Use `list` to get ALL fields on an object in one call — do NOT use `get` for individual fields. The correct pattern:
1. `sked artifacts custom-object list --json -a <alias>` — get exact object names
2. `sked artifacts custom-field list --objectName <ExactName> --json -a <alias>` — get ALL fields at once

Never guess field names or fire parallel `get` calls for individual fields. `list` returns everything you need in one request.

Note: some artifact types return "not implemented" for `list` — fall back to `get --json` with a known name, or ask the user.

### 5. Handle errors correctly

**Auth errors:** Run `sked tenant list` to check token expiry. If expired: `sked tenant login web -a <alias>`. Don't debug command syntax when it's an auth issue.

**"Not Found" errors:** Usually means wrong name/casing (e.g., `Projects` vs `Project`). List first to discover exact names: `sked artifacts custom-object list --json -a <alias>` before querying fields.

**CLI errors include stack traces** — ignore the stack, read the `message` field for the actual error. For deeper debugging: `DEBUG=*skedulo* sked <command>`.

### 6. Confirm before destructive operations

**Always ask the user before:**
- Any `delete` command (data loss, cascade effects)
- `sked package register` (irreversible — name cannot be changed)

**Safety:** Use `--dryRun` on package deploys. Prefer `upsert` (create/update are deprecated). Deleting Lookup fields cascades to Has-many relationships.

## Artifact Model

Understand what each artifact IS before choosing which to modify. See cli-reference.md for full descriptions.

**Key relationships:**
- **horizon-page** is just a pointer (name, slug, published flag) → to change the UI, update the **horizon-template** it references
- **horizon-template** contains the actual UI code (bundled: JSON + source directory)
- **function** artifact is metadata + source bundle → the code lives in the `source` directory
- **triggered-action** fires on data events and calls a URL (usually a function) → discover the function URL via `list` first
- **webhook** defines a GraphQL subscription → the `query` field contains the subscription logic
- **custom-object** defines the schema → **custom-field** defines individual fields on that object
- **web-extension** is a bundled UI artifact deployed into the Skedulo web app

**Artifact availability varies by tenant.** Not all artifact types are enabled on every tenant — some may be in alpha/beta with limited rollout. If an artifact command fails unexpectedly, the type may not be enabled on that tenant. Check a different tenant or ask the user.

## Quick Reference

| Task | Pattern |
|------|---------|
| Upsert artifact | `sked artifacts <type> upsert -f <file> -a <alias>` |
| Inspect artifact | `sked artifacts <type> get --name <Name> --json -a <alias>` |
| List artifacts | `sked artifacts <type> list --json -a <alias>` |
| Deploy package | `sked package deploy local -p <path> -a <alias>` |
| Dry-run deploy | add `--dryRun` to deploy command |
| Check auth | `sked tenant list` |
| Re-auth | `sked tenant login web -a <alias>` |

## Notes

- **Singular type names:** `sked artifacts function` NOT `functions`. All types are singular: `function`, `webhook`, `custom-field`, `custom-object`, `horizon-page`, `triggered-action`, `web-extension`, `user-role`. When unsure, run `sked artifacts --help`.
- **Async deploys:** `-w` controls wait time (default 900s). Check output for status.
- **Identifiers:** Most use `--name`; `horizon-page` uses `--slug`; `custom-field` needs `--name` + `--objectName`.
- **Full reference:** See cli-reference.md for complete command syntax and artifact JSON schemas.
