# Permission Key Catalogue

Permission keys are dot-namespaced under `skedulo.tenant.<group>[.<sub>...]`. A role's `permissionPatterns` is a list of these keys; a trailing `*` is a wildcard expanded at resolution time.

This catalogue is **captured from a live Skedulo tenant** (the three default roles) — it is the authoritative set of keys observed in practice, grouped by namespace. It is **not guaranteed exhaustive**: the platform may expose additional keys gated behind feature flags or vendors (see "Gated permissions" below). When in doubt, retrieve a default role on the target tenant and copy the exact key — do not invent keys.

> **Keys are validated at deploy.** `sked artifacts user-role upsert` rejects any key the tenant doesn't recognise: `Cannot create/update role '<name>': these permissions do not exist: [<key>]`, and the whole deploy fails. This is good — a typo or an invented key is caught at deploy, not silently ignored. It also means **not every group has every sub-key**: e.g. `skedulo.tenant.resource.view` does **not** exist (the `resource` group is wildcard-only); only the keys below (and their `*` wildcards) are known to deploy. Verified against a live tenant (2026-06).

## How to read this

- `*` after a group = a wildcard that grants the whole group.
- A specific key (e.g. `data.view`) grants exactly that one capability — the least-privilege building block.
- `web.access` is special: it is what lets a human user log into the web app at all. A web user with zero other permissions still needs it; an API-token-only role can omit it.

## Captured keys by group

| Group | Keys observed | Notes |
|---|---|---|
| `attachments` | `attachments.*` | File attachments on records |
| `auth.roles` | `auth.roles.view` | View roles/permissions (admin-ish read) |
| `availability` | `availability.*` | Resource availability / unavailability |
| `config` | `config.organization.view`, `config.user.*`, `config.variables.view`, `config.environments.view` | Tenant configuration. `config.variables.view` = read config variables |
| `data` | `data.view`, `data.modify`, `data.events.view.simple` | Core record read/write. `data.modify` is the main write grant |
| `extension` | `extension.view`, `extension.packages.view` | Installed extensions / packages |
| `files` | `files.*`, `files.view` | File storage |
| `geoservices` | `geoservices.*` | Geocoding, routing, timezone |
| `integration` | `integration.view`, `integration.modify` | Integration config (used by Paragon etc.). Present on `Resource` |
| `lists` | `lists.view`, `lists.views.view`, `lists.views.user.modify` | Saved lists + list views |
| `mobile` | `mobile.v2` | Mobile app v2 access. Present on `Resource` |
| `notifications` | `notifications.deviceInfo.view`, `notifications.push.device.list`, `notifications.push.device.register`, `notifications.push.send`, `notifications.sms.send`, `notifications.template.view` | Push + SMS. Some gated by `useMessaging` / `useNotificationV3` |
| `optimization` | `optimization.*` | Scheduling optimization. Gated by `useOptimization` |
| `pages` | `pages.view` | Platform Pages |
| `resource` | `resource.*` | Resource records |
| `resourceTracking` | `resourceTracking.*` | Live resource location tracking |
| `savedViews` | `savedViews.viewStates.view`, `savedViews.viewStates.user.modify`, `savedViews.viewTypes.view`, `savedViews.viewTypes.user.modify` | Saved view states / types |
| `schedule` | `schedule.*`, `schedule.allocation.confirm`, `schedule.allocation.decline` | Scheduling. `schedule.*` is the broad grant; the `allocation.*` keys are the narrow resource-facing actions |
| `schema` | `schema.view`, `schema.vocabulary.view` | Data-model schema + vocabularies |
| `web` | `web.access` | Log in to the web app |

## Default-role permission sets (verbatim, for cloning)

These are the exact `permissionPatterns` of the three platform defaults. Copy from these as a starting point for a custom role, then trim.

### Administrator (`custom: false`, immutable — never author)

```json
["skedulo.tenant.*"]
```

### Scheduler (`custom: false` — name fixed, can create/allocate/dispatch)

```json
[
  "skedulo.tenant.attachments.*",
  "skedulo.tenant.auth.roles.view",
  "skedulo.tenant.availability.*",
  "skedulo.tenant.config.organization.view",
  "skedulo.tenant.config.user.*",
  "skedulo.tenant.config.variables.view",
  "skedulo.tenant.data.modify",
  "skedulo.tenant.data.view",
  "skedulo.tenant.data.events.view.simple",
  "skedulo.tenant.extension.packages.view",
  "skedulo.tenant.extension.view",
  "skedulo.tenant.files.*",
  "skedulo.tenant.geoservices.*",
  "skedulo.tenant.lists.view",
  "skedulo.tenant.lists.views.user.modify",
  "skedulo.tenant.lists.views.view",
  "skedulo.tenant.notifications.deviceInfo.view",
  "skedulo.tenant.notifications.push.device.list",
  "skedulo.tenant.notifications.push.send",
  "skedulo.tenant.notifications.sms.send",
  "skedulo.tenant.notifications.template.view",
  "skedulo.tenant.optimization.*",
  "skedulo.tenant.pages.view",
  "skedulo.tenant.resource.*",
  "skedulo.tenant.resourceTracking.*",
  "skedulo.tenant.savedViews.viewStates.view",
  "skedulo.tenant.savedViews.viewStates.user.modify",
  "skedulo.tenant.savedViews.viewTypes.view",
  "skedulo.tenant.savedViews.viewTypes.user.modify",
  "skedulo.tenant.schedule.*",
  "skedulo.tenant.schema.view",
  "skedulo.tenant.schema.vocabulary.view",
  "skedulo.tenant.web.access"
]
```

### Resource (`custom: false` — name fixed, executes work, mobile + integration)

```json
[
  "skedulo.tenant.attachments.*",
  "skedulo.tenant.config.environments.view",
  "skedulo.tenant.config.organization.view",
  "skedulo.tenant.config.user.*",
  "skedulo.tenant.data.modify",
  "skedulo.tenant.data.view",
  "skedulo.tenant.extension.packages.view",
  "skedulo.tenant.extension.view",
  "skedulo.tenant.files.view",
  "skedulo.tenant.geoservices.*",
  "skedulo.tenant.integration.view",
  "skedulo.tenant.integration.modify",
  "skedulo.tenant.lists.view",
  "skedulo.tenant.lists.views.user.modify",
  "skedulo.tenant.lists.views.view",
  "skedulo.tenant.pages.view",
  "skedulo.tenant.mobile.v2",
  "skedulo.tenant.notifications.push.device.register",
  "skedulo.tenant.savedViews.viewStates.view",
  "skedulo.tenant.savedViews.viewStates.user.modify",
  "skedulo.tenant.savedViews.viewTypes.view",
  "skedulo.tenant.savedViews.viewTypes.user.modify",
  "skedulo.tenant.schedule.allocation.confirm",
  "skedulo.tenant.schedule.allocation.decline",
  "skedulo.tenant.schema.view",
  "skedulo.tenant.schema.vocabulary.view"
]
```

## Gated permissions

Some permissions are hidden unless the tenant has the relevant feature flag (or is on the matching vendor platform). On a tenant that lacks the flag the key may not be registered at all — in which case `upsert` **rejects** it (`these permissions do not exist`), same as any unknown key. Either way, verify the required flag is enabled on each target tenant before granting a gated permission.

| Feature flag | Gates (examples) |
|---|---|
| `useRecordAccessPolicies` | record-access-policy view/modify permissions |
| `useOptimization` | `skedulo.tenant.optimization.*` |
| `useMessaging` | messaging / SMS send permissions |
| `useNotificationV3` | push-notification device permissions |
| `usePackagingV2` | package dry-run / deploy permissions |

When a role depends on a gated capability, note the required feature flag in `SPEC.md` and verify the flag is enabled on each target tenant.

## Wildcard expansion rule

A pattern ending in `*` expands to **every key under that namespace at resolution time** — including keys added in future platform releases. This makes `schedule.*` convenient for a broad scheduling role but unsuitable for a tightly scoped one, since a later release could widen what the role can do without you editing it. Prefer specific keys for least-privilege roles; reserve wildcards for roles that genuinely own the whole group.
