# Skedulo Pulse User Roles

Define, edit, review, and deploy Skedulo Pulse user roles — named sets of permission-pattern glob keys (e.g. `skedulo.tenant.schedule.*`) that control what a user can do.

## Use this skill when

- Creating a custom role or editing an existing one
- Designing or auditing permission patterns
- Cloning a default role's patterns into a new custom role
- Deploying a role via `sked artifacts user-role`

## Key rules

- Always author with `custom: true`; never re-create, rename, or upsert the defaults (`Administrator` / `Scheduler` / `Resource`)
- Max 20 custom roles per tenant
- Permission keys are dot-namespaced under `skedulo.tenant.…`; a trailing `*` is a wildcard
- Grant least privilege — over-granting is a security risk, under-granting blocks users
- Retrieve default roles only to copy their patterns for reference, never to redeploy them

## Example

```json
{
  "name": "Auditor",
  "description": "Read-only access to schedule data",
  "custom": true,
  "permissionPatterns": ["skedulo.tenant.schedule.read", "skedulo.tenant.reports.*"]
}
```
