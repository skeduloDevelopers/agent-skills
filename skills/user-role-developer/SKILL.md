---
name: user-role-developer
description: This skill enables Claude to define, edit, review, and deploy Skedulo Pulse user roles — named sets of permission patterns (glob keys like skedulo.tenant.schedule.*) that control what a user can do in a tenant. Covers the UserRole state-file schema, the captured permission-key catalogue, least-privilege authoring, platform-default protections, and the sked CLI surface. Role/permission design is on the critical path of every implementation — over-granting is a security risk, under-granting blocks users.
---

# Skedulo Pulse User Roles

A **user role** is a named bundle of **permission patterns** that determines what a user can do
in a Skedulo tenant. Every user is assigned a role; the role's `permissionPatterns` (glob-style
keys such as `skedulo.tenant.schedule.*`) expand at resolution time into the concrete
permissions the user holds. Creating a custom role also registers a matching `UserType` in the
data-model vocabulary so the role becomes assignable to users; deleting the role deactivates
that entry (this is automatic — never author a `UserType` separately).

Roles are managed in **Pulse Web → Settings → Permissions / Roles** and via the
`sked artifacts user-role` CLI surface this plugin wraps.

## Goal

Produce deploy-ready user-role artifacts: one valid `src/user-roles/<Name>.user-role.json` per
custom role, with a least-privilege permission set drawn from `references/permission-keys.md`,
tracked in SPEC.md, and reviewed against `references/review-checklist.md`.

## Guardrails

Platform rules you can't discover by reading the workspace — violations mutate platform
behaviour or hard-fail at deploy. This section is the single source for these rules; everything
else in the plugin points here.

- **Never author a state file for `Administrator`, `Scheduler`, or `Resource`** — the platform
  defaults that ship on every tenant (never re-created, renamed, or deleted) — **and never set
  `custom: false`**. `custom` is always the JSON boolean `true` (not the string `"true"`);
  `false` appears only on retrieved defaults, which are reference-only — copy their patterns
  into a new custom role, never upsert them back.
- **Never grant `skedulo.tenant.*` on a custom role** — that single wildcard is the full-admin
  grant; a role that needs everything should be the admin default, not a custom role.
- **Max 20 custom roles per tenant** — the 21st create is rejected (updates to existing roles
  don't count against the limit).
- **There are no granular view keys** — `schedule.view`, `resource.view`, and
  `availability.view` do not exist; those groups are wildcard-only. Record reads go through
  `skedulo.tenant.data.view` (writes through `data.modify`). Any nonexistent key hard-fails the
  whole deploy with `these permissions do not exist: [<key>]` — use only keys from
  `references/permission-keys.md` or copied verbatim from a retrieved default.
- **`permissionPatterns` must be non-empty** — an empty array is rejected with
  `permissionPatterns should not be empty`.
- **Filename is exactly `<name>.user-role.json`** (role `Auditor` →
  `src/user-roles/Auditor.user-role.json`) — this matches what
  `sked artifacts user-role get` emits, so files round-trip cleanly between tenant and
  workspace. Quote paths for names with spaces.
- **Renaming a role = delete + recreate** — it orphans every user assigned to the old name and
  the old `UserType` vocabulary entry. Migrate user assignments before deleting any role.

---

## State File Shape

**File**: `src/user-roles/<Name>.user-role.json`

```json
{
  "metadata": { "type": "UserRole" },
  "name": "Auditor",
  "description": "Read-only access for compliance review — can view jobs, resources, lists, and pages but cannot modify anything.",
  "custom": true,
  "permissionPatterns": [
    "skedulo.tenant.web.access",
    "skedulo.tenant.data.view",
    "skedulo.tenant.lists.view",
    "skedulo.tenant.pages.view",
    "skedulo.tenant.schema.view"
  ]
}
```

Exactly five top-level keys, all required by the platform validator (each carries
`@IsNotEmpty`):

| Key | Notes |
|---|---|
| `metadata.type` | Must be exactly `"UserRole"` |
| `name` | The artifact key, matched verbatim (case-sensitive) on `get` / `upsert` / `delete`. Human-readable, Title Case by convention, no leading/trailing whitespace (rejected by the platform), not a reserved default name (see Guardrails). |
| `description` | Non-empty, human-readable purpose |
| `custom` | Boolean flag distinguishing authored roles from platform defaults (see Guardrails) |
| `permissionPatterns` | Array of permission-key strings — specific keys and/or `*` wildcards (see Guardrails for validity rules) |

## Permission Patterns & Least Privilege

Permission keys are dot-namespaced under `skedulo.tenant.<group>[.<sub>...]`; a trailing `*`
wildcard expands to every key under that namespace at resolution time — including keys added in
future platform releases. The authoritative captured catalogue, the verbatim default-role
pattern sets for cloning, the feature-flag-gated keys, and the wildcard expansion rule all live
in `references/permission-keys.md`.

- **Start narrow, widen on demand**: begin with the specific keys a role provably needs
  (`skedulo.tenant.data.view`), and use a group wildcard (`skedulo.tenant.schedule.*`) only
  when the role genuinely owns the whole group. Adding a permission after a user reports being
  blocked is far safer than discovering an over-broad wildcard exposed something it shouldn't.
- **Clone-and-trim**: for most field-ops roles the fastest safe start is copying a default
  role's captured pattern set from the catalogue, then removing the groups the new role
  shouldn't have — every key is guaranteed real, and you only reason about removals.
- **Gated keys**: some permissions only exist on tenants with a feature flag enabled (see the
  catalogue's "Gated permissions" section). Note any such dependency in SPEC.md and verify the
  flag on each target tenant.

### `web.access`

`skedulo.tenant.web.access` is what lets a human user log in to the web app at all — include it
for any human web role (even a read-only one). Omit it for a role used only by an API token:
the user can't log in, but the token still exercises the granted permissions.

## Roles vs Record Access Policies

Roles grant **capabilities** (what actions a user can perform); Record Access Policies (RAP)
restrict **which records** a user sees (row-level filters). They compose: a Dispatcher role + a
region RAP = "can dispatch, but only sees their region's jobs". Row-level scoping is never a
permission pattern — RAP is a separate artifact; document the dependency in SPEC.md when a role
needs it.

## CLI Surface

```bash
sked artifacts user-role list   -a <alias> --output json                  # list all roles + description + custom flag
sked artifacts user-role get    -a <alias> --name <NAME> -o <outputdir>   # write <NAME>.user-role.json to outputdir
sked artifacts user-role upsert -a <alias> -f <state-file> -w 900         # create or update from a state file
sked artifacts user-role delete -a <alias> --name <NAME>                  # delete a custom role
```

- `-a <alias>` is the tenant alias from `sked tenant list` — always require it explicitly,
  never default silently.
- `upsert` is create-or-update by `name` (read from the state file — you only need `-f` and
  `-a`); there is no separate `create` step.
- `delete` is for custom roles only, and there is no `inactive` status — to soft-remove a role,
  reassign its users first, then delete (see Guardrails on orphaning).
- Deploy commands, the production packaging gate, and the error-code table live in
  `commands/deploy.md`.

## Workspace Layout (in the consuming project)

```text
<project>/                                   # project root = sked package root
├── skeduloPackage.json
├── SPEC.md                                  # role spec, progress tracking
└── src/
    └── user-roles/
        ├── Auditor.user-role.json
        └── Regional Dispatcher.user-role.json
```

Flat files, one per role, under `src/user-roles/` — matching the standard project layout. The project root (the directory
holding `skeduloPackage.json`) is a valid `sked` package directory, so the project can also be
deployed whole via package mode. User-role files have no inter-artifact dependencies on each
other, so deploy order among them does not matter.

## Authoring Workflow

1. **Plan** the roles (name, persona, capability set) in SPEC.md with least privilege in mind.
2. **Author** one state file per custom role, per the shape and Guardrails above.
3. **Review** against `references/review-checklist.md` (inline in the build agent, or
   `/user-role:review`).
4. **Deploy** explicitly via `/user-role:deploy --alias <alias>`.
5. **Verify** in Pulse Web (Settings → Permissions), then **assign users** to the role — user
   assignment is an operational step, not part of this plugin.
