# Skedulo Pulse Record Access Policies

Define, edit, review, and deploy Skedulo Pulse Record Access Policies (RAP) — row-level security policies whose deny/allow EQL rules control which records each user can see.

## Use this skill when

- Restricting users to their region's, allocation's, or account's data
- Creating or editing a `*.record-access-policy.json` state file
- Choosing which roles, permissions, packages, or integration users to exclude from a rule
- Deploying a policy via `sked artifacts record-access-policy`

## Key rules

- A deny rule keeps only what matches; per object, deny filters AND together, allow filters OR together, then `(deny) OR (allow)`
- Only `{{userId}}` and `{{resourceId}}` placeholders, quoted; no bound lookups like `Region.Name` — use subqueries
- Never exclude `Administrator`; every `rolesExcluded` name must already exist on the tenant
- Max 10 policies per tenant, 20 rules per policy
- Upsert deletes then recreates rules — a bad role name or filter leaves partial rules; start policies disabled and test on a sandbox

## Example

```json
{
  "metadata": { "type": "RecordAccessPolicy" },
  "name": "Resource sees own work",
  "description": "Resources only see jobs they are allocated to",
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
