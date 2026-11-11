---
name: record-access-policy-developer
description: This skill enables Claude to define, edit, review, and deploy Skedulo Pulse Record Access Policies (RAP) — row-level security policies whose deny/allow rules inject EQL filters into every query, controlling which records each user can see or change. Covers the RecordAccessPolicy state-file schema, how deny and allow rules combine, the {{userId}} / {{resourceId}} placeholders, hasLookup pattern rules, role and permission exclusions, platform limits, lockout and partial-upsert risks, and the sked CLI surface. A wrong filter either leaks data or locks users out of the web and mobile apps.
---

# Skedulo Pulse Record Access Policies

A **Record Access Policy (RAP)** is a named, enabled-or-disabled group of up to 20 **rules**. Each
rule targets one object type, carries an EQL `filter`, and is either `deny` or `allow`. When a user
queries or mutates data, the platform resolves every rule from every enabled policy that applies to
that user and adds the filters to the query — for the root object, its lookups, and its has-many
relationships at any depth. RAP applies to the web app, the mobile app, and the APIs.

Roles grant **capabilities** (what a user can do); RAP restricts **which records** they see. The two
compose: a Dispatcher role plus a region RAP means "can dispatch, but only in my regions". Roles are
a separate artifact and plugin (`user-role`).

Policies are managed in **Pulse Web → Settings → Permissions → Record access policies** and via the
`sked artifacts record-access-policy` CLI surface this plugin wraps.

## Goal

Produce deploy-ready RAP artifacts: one valid
`src/record-access-policies/<name>.record-access-policy.json` per policy, with filters that grant
exactly the intended visibility, exclusions for every role or integration that must keep seeing all
data, tracked in SPEC.md, and reviewed against `references/review-checklist.md`.

## Guardrails

Platform rules you can't discover by reading the workspace — violations hard-fail at deploy, leak
data, or lock users out. This section is the single source for these rules; everything else in the
plugin points here.

- **Read `deny` as "keep only what matches".** A deny rule hides every record that does *not* match
  its filter. For the same object, deny filters are joined with **AND**, allow filters with **OR**,
  and the result is `(all deny filters) OR (any allow filter)`. An allow rule only widens access a
  deny took away — on the same object, in another policy, or through a mandatory lookup (an allow on
  Jobs can override a deny on Regions that would otherwise hide the job).
- **Only two placeholders exist: `{{userId}}` and `{{resourceId}}`** (spaces inside the braces are
  fine). Any other `{{name}}` is rejected (`invalid_template_field`), and so is an unquoted one
  (`invalid_filter`) — always quote them: `UserId == '{{userId}}'`. For a
  user with no resource record, `{{resourceId}}` resolves to an ID that matches nothing.
- **No bound lookups in filters.** `Region.Name == 'North'` is rejected; use a subquery:
  `RegionId IN (SELECT UID FROM Regions WHERE Name == 'North')`. Every field and object a filter
  names must exist on the tenant — filters are validated against the tenant schema at save.
- **Never put `Administrator` in `rolesExcluded`** — the platform rejects it. Administrators already
  bypass RAP: a user holding both `skedulo.tenant.data.viewAll` and `skedulo.tenant.data.modifyAll`
  gets no rules (`viewAll` alone skips RAP for reads, `modifyAll` alone for writes).
- **`rolesExcluded` holds role names, matched exactly** (case-sensitive) against the tenant's roles;
  `permissionsExcluded` holds real permission keys (an unknown key fails with `invalid_permission`).
  No duplicates in `rolesExcluded`. A user who has *any* listed role or permission skips that rule. Always write both arrays, `[]` when empty.
- **Upsert is not atomic.** On an existing policy, upsert updates the policy, **deletes every rule,
  then recreates them**. Role names are resolved after the delete, so a missing role name, an
  unknown permission key, or an invalid filter leaves the policy enabled with no rules or only some
  of them. Every name in `rolesExcluded` must already exist on the tenant before deploy (deploy user roles first).
- **Limits:** 10 policies per tenant, 20 rules per policy; `name` ≤ 250 characters with no
  leading/trailing whitespace; policy `description` ≤ 1000; rule `description` ≤ 250.
- **Names are unique per tenant ignoring case, but upsert matches them exactly.** Upserting `foo`
  when the tenant holds `Foo` takes the create path and fails with `A policy named 'foo' already
  exists`. Keep the
  file name, `name`, and the tenant's spelling identical. Filename is exactly
  `<name>.record-access-policy.json` — what `sked artifacts record-access-policy get` emits.
- **Lockout risk.** A wrong deny rule on `Users`, `Resources`, or `Regions` can break the web or
  mobile app for everyone it applies to. Author new policies with `"enabled": false`, or exclude
  every role except a dedicated test role, until verified on a sandbox.
- **Pulse-only, feature-flagged.** RAP needs the tenant flag `useRecordAccessPolicies`; confirm it
  on each target tenant. On Salesforce-flavor tenants the CLI reports
  `record-access-policy is not a sked command`.

The plugin's `PostToolUse` hook (`scripts/validate_record_access_policies.py`) enforces the shape,
name, limit, placeholder (unknown or unquoted), `accessType`, and `Administrator` rules above on every Write/Edit of a
state file. It warns (without blocking) on likely bound lookups, enabled
policies with no rules, allow rules with no matching deny rule, and kebab-case names; legacy names
already deployed go in `src/record-access-policies/naming-exceptions.json` (`{"names": [...]}`).

---

## State File Shape

**File**: `src/record-access-policies/<name>.record-access-policy.json`

```json
{
  "metadata": { "type": "RecordAccessPolicy" },
  "name": "Resource sees own work",
  "description": "Resources only see the jobs they are allocated to.",
  "enabled": false,
  "rules": [
    {
      "description": "Deny Jobs unless allocated to the current resource",
      "objectType": "Jobs",
      "filter": "UID IN (SELECT JobId FROM JobAllocations WHERE ResourceId == '{{resourceId}}' AND Status != 'Deleted' AND Status != 'Declined')",
      "accessType": "deny",
      "permissionsExcluded": [],
      "rolesExcluded": ["Scheduler"]
    }
  ]
}
```

| Key | Notes |
|---|---|
| `metadata.type` | Exactly `"RecordAccessPolicy"` |
| `name` | Artifact key, matched exactly on `get` / `upsert` / `delete`. Sentence case by convention (`Data isolation by region`) |
| `description` | Non-empty, ≤ 1000 characters |
| `enabled` | JSON boolean. Disabled policies are stored but resolve no rules |
| `rules` | Optional array, ≤ 20. Omitted or `[]` means the policy restricts nothing |

Each rule:

| Key | Notes |
|---|---|
| `description` | Non-empty, ≤ 250 characters — say what the rule keeps, e.g. "Deny Jobs unless …" |
| `objectType` | GraphQL object name (`Jobs`, `Resources`, a custom object) **or** a pattern `hasLookup:<LookupName>` |
| `filter` | EQL, valid for `objectType`, no bound lookups, placeholders quoted |
| `accessType` | `"deny"` or `"allow"` |
| `permissionsExcluded` | Permission keys whose holders skip this rule, e.g. `skedulo.tenant.data.viewAll` |
| `rolesExcluded` | Role names whose holders skip this rule; never `Administrator` |

## Rule Semantics

- **Pattern rules.** `objectType: "hasLookup:Region"` applies the rule to every object that has a
  lookup *named* `Region` (matched by relationship name, not target type), so one rule covers Jobs,
  Resources, Accounts, custom objects and more. Use `RegionId` in the filter.
- **Lookups and children.** When a rule hides a record reached through a mandatory lookup, the parent
  record is hidden too; through an optional lookup, the lookup comes back `null`. Has-many lists show
  only the permitted children.
- **Mutations.** The user must be able to see the record before and after the change, and every
  lookup ID they set must also be visible. One failing record fails the whole bulk mutation. Inserting
  a record whose rule filters through a related record that doesn't exist yet fails — insert both in
  one mutation with `idAlias`.
- **Not covered by RAP:** `CreatedBy` / `LastModifiedBy` lookups, change history, the rule conflicts
  console, and Custom Forms data.
- **Automation.** Webhooks and triggered actions run as an admin API user, so RAP does not filter
  them. Connected functions and integrations see what their calling token's user sees — exclude that
  user's role (or give it `viewAll` / `modifyAll`) when it must read all data.
- **Subscriptions** keep the rules they started with until they reconnect.

Worked patterns (by region, by allocation, by ownership, by a custom user-details object) and the
exclusions installed packages need live in `references/isolation-patterns.md`.

## CLI Surface

```bash
sked artifacts record-access-policy list   -a <alias> --json                         # {"result": [{name, description, enabled}]}
sked artifacts record-access-policy get    -a <alias> --name "<NAME>" -o <outputdir>   # writes <NAME>.record-access-policy.json
sked artifacts record-access-policy upsert -a <alias> -f <state-file> -w 900           # create or replace rules (non-atomic)
sked artifacts record-access-policy delete -a <alias> --name "<NAME>"                  # delete policy and its rules
```

- `-a <alias>` is the tenant alias from `sked tenant list` — always require it explicitly.
- `create` and `update` are deprecated; use `upsert`.
- To inspect what a specific user actually gets, call the tenant's
  `GET /authorization/policies/rules/resolved` endpoint as that user.
- Deploy commands, the production packaging gate, and the error table live in `commands/deploy.md`.

## Workspace Layout (in the consuming project)

```text
<project>/                                   # CX project root = sked package root
├── skeduloPackage.json
├── SPEC.md                                  # policy spec, progress tracking
└── src/
    ├── user-roles/                          # roles named in rolesExcluded (deploy first)
    └── record-access-policies/
        ├── Data isolation by region.record-access-policy.json
        └── Resource sees own work.record-access-policy.json
```

The platform deploys RAP after user roles (rules reference roles by name) and after the data model
(rules reference objects and fields). Policies have no dependencies on each other.

## Authoring Workflow

1. **Plan** each policy in SPEC.md: who is restricted, what they keep, which roles, permissions,
   packages, and integration users are excluded, and the target objects.
2. **Confirm the schema** — every object, field, and lookup the filters name — with the
   `graphql-schema` MCP or `references/tenant-auth.md`'s introspection fallback.
3. **Author** one state file per policy, starting `"enabled": false`.
4. **Review** against `references/review-checklist.md` (inline in the build agent, or
   `/record-access-policy:review`).
5. **Deploy** explicitly via `/record-access-policy:deploy --alias <alias>` to a sandbox, sign in as a
   restricted test user on web and mobile, then enable.
