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

Query the platform instead of asking the user. Pattern: `sked artifacts <type> list --json -a <alias>`. Use it to get function URLs, introspect schemas (`--objectName` for custom-field), check webhooks, etc. Be self-sufficient.

### 5. Handle auth errors correctly

On auth errors: run `sked tenant list` to check token expiry. If expired: `sked tenant login web -a <alias>`. Don't debug command syntax when it's an auth issue. For deeper debugging: `DEBUG=*skedulo* sked <command>`.

### 6. Confirm before destructive operations

**Always ask the user before:**
- Any `delete` command (data loss, cascade effects)
- `sked package register` (irreversible — name cannot be changed)

**Safety:** Use `--dryRun` on package deploys. Prefer `upsert` (create/update are deprecated). Deleting Lookup fields cascades to Has-many relationships.

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

- **Async deploys:** `-w` controls wait time (default 900s). Check output for status.
- **Identifiers:** Most use `--name`; `horizon-page` uses `--slug`; `custom-field` needs `--name` + `--objectName`.
- **Full reference:** See cli-reference.md for complete command syntax and artifact JSON schemas.
