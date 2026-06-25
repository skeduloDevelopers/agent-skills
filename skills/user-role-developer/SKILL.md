---
name: user-role-developer
description: This skill enables Claude to define, edit, review, and deploy Skedulo Pulse user roles — named sets of permission patterns (glob keys like skedulo.tenant.schedule.*) that control what a user can do. Custom roles are authored per tenant (max 20); the default roles Administrator / Scheduler / Resource ship with the platform and must never be re-created or renamed. Role/permission design is on the critical path of every implementation — over-granting is a security risk, under-granting blocks users.
---

# Skedulo Pulse User Roles Skill

## What is a User Role in Pulse?

A **user role** is a named bundle of **permission patterns** that determines what a user can do in a Skedulo tenant. Every user is assigned a role; the role's `permissionPatterns` (glob-style keys such as `skedulo.tenant.schedule.*`) expand at resolution time into the concrete permissions the user holds.

Each user role has:

- a **`name`** — the unique identifier and the artifact key (e.g. `Auditor`, `Regional Dispatcher`),
- a **`description`** — a human-readable summary of what the role is for,
- a **`custom`** flag — `true` for roles you author, `false` for the platform's built-in defaults,
- a list of **`permissionPatterns`** — the permission keys / wildcards the role grants.

User roles are managed in **Pulse Web → Settings → Permissions / Roles**, and via the `sked artifacts user-role` CLI surface this plugin wraps. Creating a custom role also registers it as a `UserType` in the data-model vocabulary, so the role becomes assignable to users.

## Default Roles vs Custom Roles

| | Default roles | Custom roles |
|---|---|---|
| Examples | `Administrator`, `Scheduler`, `Resource` | `Auditor`, `Regional Dispatcher`, anything you create |
| `custom` | `false` | `true` |
| Editable? | Reference-only in this plugin — never author or upsert any default. (`Administrator` is platform-locked; `Scheduler` / `Resource` are editable at the platform level, but that is out of scope here — clone their patterns into a new custom role instead.) | Fully editable / deletable |
| Count limit | 3, fixed | **Max 20 per tenant** |
| Created by | The platform, on every tenant | You, via this plugin |

**The three default roles exist on every tenant and must never be re-created, renamed, or deleted.**

- **`Administrator`** — super user. Permissions are the single wildcard `skedulo.tenant.*` (everything). Immutable — do not author or upsert an `Administrator` state file.
- **`Scheduler`** — can create, allocate, and dispatch work (~33 patterns). Reference-only here: copy its patterns into a custom role; do not author or upsert `Scheduler`.
- **`Resource`** — can execute work (~26 patterns, includes `skedulo.tenant.integration.*` and `skedulo.tenant.mobile.v2`). Reference-only here: copy its patterns into a custom role; do not author or upsert `Resource`.

Retrieve a default role to **copy** its permission patterns as a starting point for a custom role — never to re-deploy the default itself. See `references/permission-keys.md` for the full captured permission catalogue and each default role's pattern set.

## The `custom` Flag

| `custom` | Meaning | When to use |
|---|---|---|
| `true` | A tenant-specific role you authored. Stored in the tenant's `custom_roles`. | **Every role you create with this plugin.** |
| `false` | A platform-managed default (`Administrator` / `Scheduler` / `Resource`). | Only appears when you **retrieve** a default for reference. Never author a `custom: false` role. |

**Default to `custom: true` for any role you write.** A new role with `custom: false` is wrong — that namespace belongs to the platform.

## Permission Patterns

Permission keys are dot-namespaced under `skedulo.tenant.<group>[.<sub>...]`. A role's `permissionPatterns` is a list of these keys, where a trailing `*` is a wildcard that expands to every key under that namespace at resolution time.

```text
skedulo.tenant.schedule.*           → every scheduling permission (wildcard)
skedulo.tenant.data.view            → a single, specific permission
skedulo.tenant.data.modify          → a single, specific permission
skedulo.tenant.*                    → everything (Administrator only)
```

**Wildcard discipline:**

- Use a **specific key** (`skedulo.tenant.data.view`) when the role needs exactly that capability — this is the safe default and the heart of least-privilege.
- Use a **group wildcard** (`skedulo.tenant.schedule.*`) only when the role genuinely needs the whole group. A wildcard silently picks up new permissions added to that group in future platform releases — convenient for broad roles, risky for tight ones.
- **Never** use `skedulo.tenant.*` on a custom role — that is the `Administrator` grant. If a role needs everything, the user should be an Administrator.

### Permission groups (captured catalogue)

The authoritative key catalogue lives in `references/permission-keys.md`. The observed top-level groups are:

`attachments` · `auth.roles` · `availability` · `config` (`organization`, `user`, `variables`, `environments`) · `data` (`view`, `modify`, `events`) · `extension` (`view`, `packages`) · `files` · `geoservices` · `integration` · `lists` (+ `lists.views`) · `mobile` · `notifications` (`deviceInfo`, `push`, `sms`, `template`) · `optimization` · `pages` · `resource` · `resourceTracking` · `savedViews` (`viewStates`, `viewTypes`) · `schedule` (+ `schedule.allocation`) · `schema` (+ `schema.vocabulary`) · `web`

> **Don't guess permission keys — they are validated at deploy.** `upsert` rejects any key the tenant doesn't recognise with `Cannot create/update role '<name>': these permissions do not exist: [<key>]`, and the whole deploy fails. A typo, or an invented specific key (e.g. `skedulo.tenant.resource.view` — which does NOT exist; the `resource` group is wildcard-only), aborts the upsert. If unsure a key exists, retrieve a default role (`sked artifacts user-role get -a <alias> --name Scheduler`) and copy the exact key.
>
> **Not every group has a `.view` / `.modify` sub-key.** `data` has `data.view` and `data.modify`; but `schedule`, `resource`, and `availability` expose only a group wildcard (`schedule.*`, `resource.*`, `availability.*`) plus specific action keys (`schedule.allocation.confirm`, `schedule.allocation.decline`). There is no `schedule.view` / `resource.view` / `availability.view`. Reading jobs, resources, and availability is granted by `skedulo.tenant.data.view`; writing them by `skedulo.tenant.data.modify`. See `references/permission-keys.md` for the exact captured set.

### Feature-flag and vendor-gated permissions

Some permissions are hidden unless the tenant has a feature flag enabled, and some are hidden for other vendor platforms:

| Feature flag | Gated permissions (examples) |
|---|---|
| `useRecordAccessPolicies` | record-access-policy view/modify |
| `useOptimization` | `skedulo.tenant.optimization.*` |
| `useMessaging` | messaging / SMS permissions |
| `useNotificationV3` | push-notification device permissions |
| `usePackagingV2` | package dry-run / deploy permissions |

Granting a flag-gated permission on a tenant that lacks the flag may be **rejected at upsert** (the key isn't registered for that tenant, so it deploys exactly like an unknown key — `these permissions do not exist`). Confirm the required flag is enabled on each target tenant, and note the dependency in `SPEC.md` when a role relies on a gated capability.

## Naming Rules

The `name` is the artifact key and is matched verbatim (case-sensitive) on `get` / `upsert` / `delete`.

- Use a **clear, human-readable role name** — `Auditor`, `Regional Dispatcher`, `Read-only Analyst`. Title Case is conventional (matches the defaults `Administrator` / `Scheduler` / `Resource`).
- **Must not be `Administrator`, `Scheduler`, or `Resource`** — those are reserved defaults.
- **No leading / trailing whitespace** (rejected by the platform).
- Keep it stable — renaming means delete-and-recreate, which orphans every user assigned to the old role and the old `UserType` vocabulary entry.

The state file is named after the role name: role `Auditor` → `user-roles/Auditor.user-role.json`. This matches exactly what `sked artifacts user-role get` emits, so files round-trip cleanly between tenant and local workspace. (For a name with spaces, the file is `Regional Dispatcher.user-role.json` — quote the path in shell commands.)

## CLI Surface

```bash
sked artifacts user-role list   -a <alias> --output json                 # list all roles + description + custom flag
sked artifacts user-role get    -a <alias> --name <NAME> -o <outputdir>   # write <NAME>.user-role.json to outputdir
sked artifacts user-role upsert -a <alias> -f <state-file> -w 900         # create or update from a state file
sked artifacts user-role delete -a <alias> --name <NAME>                  # delete a custom role
```

The `-a <alias>` flag is the tenant alias from `sked tenant list`. **Always require the user to pass the alias explicitly** — never default silently. `upsert` reads the `name` from the state file; you only need `-f <state-file>` and `-a <alias>`.

> `upsert` is create-or-update by name: if a role with that `name` exists it is updated, otherwise it is created. There is no separate `create` step.

> **`delete` only makes sense for custom roles.** Never delete `Administrator` / `Scheduler` / `Resource`.

## Workspace Layout (in the consuming project)

```text
<project>/                                   # sked package root
├── SPEC.md                                  # role spec, feature checklist
└── user-roles/
    ├── Auditor.user-role.json
    └── Regional Dispatcher.user-role.json
```

`user-roles/` sits directly at the project root — no `src/` wrapper. This matches the canonical `sked` package layout, so the project root IS a valid `sked` package directory and can be deployed as a whole via `sked package deploy local -p .` in addition to the per-artifact `sked artifacts user-role upsert` flow. Roles have no inter-artifact dependencies, so deploy order does not matter.

---

## User Role State File

### Shape

```json
{
  "metadata": { "type": "UserRole" },
  "name": "<role name>",
  "description": "<what the role is for>",
  "custom": true,
  "permissionPatterns": [
    "skedulo.tenant.data.view",
    "skedulo.tenant.schedule.*"
  ]
}
```

| Key | Required | Notes |
|---|---|---|
| `metadata.type` | yes | Must be exactly `"UserRole"` |
| `name` | yes | Non-empty string, no leading/trailing whitespace, NOT a reserved default name (`Administrator` / `Scheduler` / `Resource`). This is the artifact key. |
| `description` | yes | Human-readable purpose. Non-empty. |
| `custom` | yes | Boolean. **`true` for every role you author.** `false` only on retrieved defaults. |
| `permissionPatterns` | yes | **Non-empty** array of permission-key strings (specific keys and/or `*` wildcards). Every key must exist on the tenant or the upsert is rejected. An empty array is rejected (`permissionPatterns should not be empty`) — every role needs at least one permission. |

All four data fields are required by the platform validator — in the schema `name`, `description`, `custom`, and `permissionPatterns` each carry `@IsNotEmpty`. Note `custom` is a required **boolean**: `true` for authored roles, `false` only on retrieved defaults — both values are valid (for a boolean, `@IsNotEmpty` simply requires the field be present, not that it be `true`). There is no optional field in v0.1.

### Validation constraints (enforced by the platform / CLI)

- **`name`, `description`, `custom`, `permissionPatterns` are all required.** A missing or empty value is rejected at upsert.
- **`name` must not be a reserved default** — this plugin never upserts `Administrator`, `Scheduler`, or `Resource`. `Administrator` is platform-locked; `Scheduler` / `Resource` are editable at the platform level but treating them as reference-only here avoids mutating platform defaults. Clone their patterns into a new custom role instead.
- **`permissionPatterns` must be an array of strings, and every key must exist on the tenant.** Each entry is a permission key or wildcard. An unknown key is **rejected at upsert** (`these permissions do not exist: [<key>]`) and the whole deploy fails — typos are caught at deploy, not silently ignored. `permissionPatterns` must also be non-empty (an empty array is rejected with `permissionPatterns should not be empty`).
- **Max 20 custom roles per tenant.** The 21st `create` is rejected. (An `upsert` that updates an existing role does not count against the limit.)
- **`custom` is a JSON boolean** (`true`/`false`), not the string `"true"`.

---

## Worked Examples

### 1. Read-only "Auditor"

A role that can see records, lists, and pages but change nothing — built from real, specific view keys only (verified to deploy against a live tenant). This is the least-privilege pattern.

**File:** `user-roles/Auditor.user-role.json`

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
    "skedulo.tenant.lists.views.view",
    "skedulo.tenant.pages.view",
    "skedulo.tenant.schema.view"
  ]
}
```

Notes:
- `skedulo.tenant.data.view` is the core record-read grant — it covers viewing jobs, resources, and availability data. There is **no** `schedule.view` / `resource.view` / `availability.view` key (those would be rejected at deploy); record reads go through `data.view`, and the absence of `data.modify` is what makes the role read-only.
- `lists.view`, `lists.views.view`, `pages.view`, `schema.view` add read access to lists, list views, Platform Pages, and the data-model schema.
- `skedulo.tenant.web.access` is what lets the user log in to the web app at all — a read-only web user still needs it.

### 2. Region-scoped "Dispatcher"

A role for a dispatcher who allocates and dispatches work but should not administer the tenant. Starts from the `Scheduler` capability set, trimmed.

**File:** `user-roles/Dispatcher.user-role.json`

```json
{
  "metadata": { "type": "UserRole" },
  "name": "Dispatcher",
  "description": "Allocates and dispatches work, manages availability and resources. No tenant administration.",
  "custom": true,
  "permissionPatterns": [
    "skedulo.tenant.web.access",
    "skedulo.tenant.data.view",
    "skedulo.tenant.data.modify",
    "skedulo.tenant.schedule.*",
    "skedulo.tenant.availability.*",
    "skedulo.tenant.resource.*",
    "skedulo.tenant.lists.view",
    "skedulo.tenant.lists.views.view",
    "skedulo.tenant.notifications.sms.send",
    "skedulo.tenant.notifications.push.send",
    "skedulo.tenant.geoservices.*",
    "skedulo.tenant.pages.view",
    "skedulo.tenant.schema.view"
  ]
}
```

Notes:
- `data.view` / `data.modify` grant read / write on the underlying **records** (jobs, resources, availability); the group wildcards `schedule.*`, `availability.*`, `resource.*` grant the **actions** on those records (allocating, dispatching, editing availability/resource settings). They are complementary, not redundant — a dispatcher needs both the record write (`data.modify`) and the scheduling actions (`schedule.*`).
- No `config.*`, no `auth.roles.*`, no `integration.*` — deliberately excluded so a dispatcher can't reconfigure the tenant.
- **Record-level** scoping ("only their region's jobs") is NOT done here — `permissionPatterns` grant capabilities, not row filters. Row-level scoping is a Record Access Policy (RAP) concern, a separate artifact. Document the RAP dependency in `SPEC.md` if the role needs it.

### 3. Retrieved default (reference only — never re-deploy)

`sked artifacts user-role get -a <alias> --name Scheduler` emits a `custom: false` file. Keep it for reference / to copy patterns; do NOT upsert it back.

```json
{
  "metadata": { "type": "UserRole" },
  "name": "Scheduler",
  "description": "Able to create, allocate and dispatch work",
  "custom": false,
  "permissionPatterns": [ "skedulo.tenant.schedule.*", "skedulo.tenant.data.modify", "..." ]
}
```

---

## How a role relates to the rest of the platform

- **UserType vocabulary** — creating a custom role registers a matching `UserType` so users can be assigned to it. Deleting the role deactivates that `UserType`. This is automatic; you don't author the `UserType` separately.
- **Record Access Policies (RAP)** — roles grant *capabilities* (what actions a user can perform); RAP restricts *which records* a user sees (row-level filters). They compose: a Dispatcher role + a region RAP = "can dispatch, but only sees their region's jobs". RAP is a separate artifact — cross-reference its plugin for row-level scoping.
- **Config variables / Triggered Actions / Webhooks** — unrelated to roles; roles gate the human/API user, not these artifacts' execution.

The contract is: **author the role here with the right `permissionPatterns`, deploy it, then assign users to the role** in Pulse Web (or via the appropriate API). The plugin owns the role definition; user assignment is an operational step.

---

## Common Patterns

### Least privilege — start narrow, widen on demand

Begin a custom role with the specific `.view` / `.modify` keys it provably needs, then widen to a group wildcard only when the requirement clearly covers the whole group. It is far safer to add a permission after a user reports being blocked than to discover months later that an over-broad wildcard exposed something it shouldn't.

### Clone-and-trim from a default

For most field-ops roles, the fastest safe start is: retrieve `Scheduler` or `Resource`, copy its `permissionPatterns` into your new custom role, then **remove** the groups the new role shouldn't have. This guarantees every key is real (no typos) and you only have to reason about removals.

### A no-login service/automation role

If a role is only ever used by an API token (not a human), omit `skedulo.tenant.web.access` — the user can't log into the web app but the token can still exercise the granted data/schedule permissions.

### Soft-removing a role

There is no `inactive` status for roles (unlike config variables). To stop a role being used, reassign its users to another role first, then `delete` it. Deleting a role with users still attached orphans those users — always migrate assignments first.

---

## Authoring Workflow Recap

1. **Plan** the roles (name, who uses them, what capabilities) in `SPEC.md` before writing JSON. Decide each role's permission set with least-privilege in mind.
2. **Author** one `user-roles/<Name>.user-role.json` per custom role, always with `custom: true`. Never author a default (`Administrator` / `Scheduler` / `Resource`).
3. **Validate** JSON parses (every file) and no file uses a reserved name or `custom: false`.
4. **Review** with `/user-role:review`.
5. **Deploy** explicitly: `/user-role:deploy --alias <alias>`.
6. **Verify** in Pulse Web (Settings → Permissions), then **assign users** to the new role.

Never auto-deploy from the coding agent. Never assume a tenant alias. Never re-create or rename a default role. Never exceed 20 custom roles per tenant.
