# Skedulo CLI Skill Design

## Problem

When using Claude with the Skedulo CLI (`sked`) over long sessions, context compaction causes critical information loss — most notably the tenant alias (`-a`). This leads to commands being run against the wrong tenant, wasted debugging time, and frustrated developers. Beyond the alias issue, Claude doesn't proactively leverage CLI capabilities like `--help`, `--json`, and `list` commands that would make it more self-sufficient.

## Skill Type

Reference + technique hybrid. Behavioral rules for safe, effective CLI usage plus command reference material.

## Core Rules

### Rule 1: Always use `-a <alias>` on commands that support it

- Before running any `sked` command, check `--help` to confirm whether it supports `-a`
- If `-a` is supported, it MUST be included — no exceptions
- If the alias is not in context, ask the user — never guess, never omit it
- **Why this exists:** Context compaction silently drops the alias. Claude then deploys to the default tenant without realizing it. This has caused hours of debugging where "it deployed successfully" but the target tenant has no changes.

**Red flags (stop and check for alias):**
- About to run a `sked` command without `-a`
- "I already know which tenant" — do you? Check.
- "I'll add it next time" — add it now.
- "It's probably the default" — probably isn't good enough.

### Rule 2: Proactively use `--help`

- Before guessing at flags or syntax, run `<command> --help`
- Use it to discover useful options (e.g., `--dryRun`, `--json`, `--verbose`)
- `--help` works at every level of the command tree:
  - `sked --help` — top-level commands
  - `sked artifacts --help` — artifact types
  - `sked artifacts function --help` — operations on functions
  - `sked artifacts function list --help` — flags for a specific operation
- Use `--help` to check whether a command supports `-a` (Rule 1)

### Rule 3: Use `--json` for read-only inspection

- When you need to understand an artifact's configuration, use `get --json` or `list --json`
- Do NOT download/export artifacts (with `-o`) just to inspect them — this pollutes the repo with files that weren't there before
- Only use `-o <outputdir>` when you intend to modify the artifact
- `--json` is a global flag supported by all commands

### Rule 4: Use `list` + `--json` for discovery and introspection

Before building something that depends on existing artifacts, schemas, or URLs — query the platform:

- `sked artifacts function list --json -a <alias>` — get deployed function URLs
- `sked artifacts custom-field list --objectName <ObjectName> --json -a <alias>` — understand data model/schema
- `sked artifacts custom-object list --json -a <alias>` — see all custom objects
- `sked artifacts webhook list --json -a <alias>` — check existing webhook configurations
- `sked artifacts horizon-page list --json -a <alias>` — see deployed pages
- `sked package list --json -a <alias>` — see registered packages

This makes Claude self-sufficient — query the CLI instead of asking the user for information.

### Rule 5: Auth-aware error handling

- On auth/permission errors, first run `sked tenant list` to check token status
- If the token is expired, suggest re-authentication: `sked tenant login web -a <alias>`
- Do NOT waste time debugging command syntax when it's an auth issue
- Debug mode is available via `DEBUG=*skedulo*` environment variable for deeper issues

### Rule 6: Confirm before destructive operations

- Always confirm with the user before running any `delete` command
- Note: `upsert` is the standard write operation — `create` and `update` are deprecated
- Warn that `sked package register` is irreversible (name cannot be changed after)
- Suggest `--dryRun` on `sked package deploy local` for validation before actual deployment
- Deleting a custom field with a Lookup type also cascades to delete its Has-many relationships

## Additional Notes

### Deployments are async

The `-w` (wait) flag controls how long the CLI waits for deployment completion (default: 900 seconds). A command returning doesn't always mean deployment succeeded — check output for status.

### Command identifier patterns

- Most artifacts use `--name` as their identifier
- `horizon-page` uses `--slug` instead of `--name`
- `custom-field` requires both `--name` AND `--objectName`

### Commands that do NOT need `-a`

These are local or tenant-management commands (verify with `--help`):

- `sked tenant list` — lists all tenants globally
- `sked tenant logout` — logs out default tenant
- `sked function dev <dir>` — local dev server
- `sked function generate` — local scaffolding
- `sked web-extension dev <dir>` — local dev server

Rather than memorizing this list, always check `--help` — it's the source of truth.

## Skill Structure

```
skills/
  skedulo-cli/
    SKILL.md    # Core rules, quick reference, behavioral guidance
    cli-reference.md    # Detailed command reference (heavy reference, separate file)
```

The main SKILL.md stays focused on the six rules and quick-reference patterns. The detailed command syntax goes in a separate reference file to keep the primary skill scannable and under the token budget.

## Success Criteria

- Claude always includes `-a <alias>` on tenant-scoped commands
- Claude checks `--help` before guessing at syntax
- Claude uses `--json` for inspection instead of downloading artifacts
- Claude uses `list` for discovery instead of asking the user
- Claude catches auth errors and checks token status
- Claude confirms before destructive operations
- No regressions: these behaviors hold even after context compaction
