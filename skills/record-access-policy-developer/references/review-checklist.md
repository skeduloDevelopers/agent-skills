# RecordAccessPolicy Review Checklist

The single checklist for reviewing record-access-policy state files — used by the build agent's
review phase and `/record-access-policy:review`. Each item enforces a rule stated once in SKILL.md
(see its Guardrails for the rationale). Run `scripts/validate_record_access_policies.py --workspace .`
first; its errors are Critical.

## Schema

- JSON parses; `metadata.type` is exactly `"RecordAccessPolicy"`
- `name`, `description`, `enabled` present; `enabled` is a JSON boolean
- Every rule has all six keys; `accessType` is `deny` or `allow`; both exclusion arrays present
  (`[]` when empty)
- Within limits: ≤ 20 rules per policy, ≤ 10 policies per tenant (count the tenant's existing
  policies too), name ≤ 250, descriptions ≤ 1000 / 250

## Naming & Filename

- Filename is exactly `<name>.record-access-policy.json`, matching `name` including case
- `name` matches the tenant's existing spelling exactly when updating (case-only differences fail)

## Filters

- Every placeholder is `{{userId}}` or `{{resourceId}}`, quoted as a string
- No bound lookups (`X.Y` field paths) — subqueries only
- Every object, field, and lookup named exists on the tenant or in this project's data model
- `objectType` is a real object or `hasLookup:<LookupName>` naming a real lookup relationship
- Each deny filter describes what the user **keeps**, and its `description` says the same thing
  (no inverted "deny X" filters that match X)
- `{{resourceId}}` rules account for users with no resource record (they match nothing)

## Exclusions & Lockout

- `Administrator` never appears in `rolesExcluded`; no duplicate role names
- Every `permissionsExcluded` key is a real permission key (copied from the `user-role` catalogue or a
  retrieved role) — deploy does not pre-check them and an unknown key leaves partial rules
- Every name in `rolesExcluded` exists on the tenant before a direct upsert; for package deploys a
  role in `src/user-roles/` is enough because the package deploys roles first. A missing role breaks
  upsert midway and leaves the policy with partial rules
- Office roles, installed-package roles, and integration / connected-function users that must see
  all data are excluded (or hold `data.viewAll` + `data.modifyAll`)
- Rules on `Users`, `Resources`, and `Regions` still let each restricted user see their own user and
  resource records
- New or substantially changed policies are `"enabled": false` until verified on a sandbox, or SPEC.md
  records the sandbox verification

## Semantics

- Allow rules have a deny rule to widen — on the same object in this policy, in another policy, or via
  a `hasLookup` pattern / mandatory lookup — and SPEC.md says which
- Multiple deny rules on one object are intended to be combined with AND
- SPEC.md records the tenant feature flag (`useRecordAccessPolicies`) check and the test users used
