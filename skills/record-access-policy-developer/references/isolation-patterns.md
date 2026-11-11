# Record Access Policy Isolation Patterns

Worked rule sets for the common isolation requirements. Every filter here passes the platform's
rules: placeholders quoted, no bound lookups, subqueries for related data. Confirm each object and
field exists on the target tenant before reusing a pattern — custom objects and renamed lookups
differ per tenant.

## Data isolation by region

Based on the platform's own "Data isolation by region" template. Users see data in the regions on
their user record (`UserRegions`) and their resource's primary and secondary regions.

```json
{
  "metadata": { "type": "RecordAccessPolicy" },
  "name": "Data isolation by region",
  "description": "Users only see data associated with the regions of their user and resource records. Does not consider resource temporary regions.",
  "enabled": false,
  "rules": [
    {
      "description": "Deny Regions unless they are associated with the user",
      "objectType": "Regions",
      "filter": "UID IN (SELECT RegionId FROM UserRegions WHERE UserId == '{{userId}}') OR UID IN (SELECT PrimaryRegionId FROM Resources WHERE UID == '{{resourceId}}') OR UID IN (SELECT RegionId FROM ResourceRegions WHERE ResourceId == '{{resourceId}}' AND Status != 'Deleted' AND Status != 'Declined')",
      "accessType": "deny",
      "permissionsExcluded": [],
      "rolesExcluded": []
    },
    {
      "description": "Deny every object with a Region lookup unless its region is associated with the user",
      "objectType": "hasLookup:Region",
      "filter": "RegionId IN (SELECT RegionId FROM UserRegions WHERE UserId == '{{userId}}') OR RegionId IN (SELECT PrimaryRegionId FROM Resources WHERE UID == '{{resourceId}}') OR RegionId IN (SELECT RegionId FROM ResourceRegions WHERE ResourceId == '{{resourceId}}' AND Status != 'Deleted' AND Status != 'Declined')",
      "accessType": "deny",
      "permissionsExcluded": [],
      "rolesExcluded": []
    },
    {
      "description": "Deny Users unless they are the current user or share a region with them",
      "objectType": "Users",
      "filter": "UID == '{{userId}}' OR UID IN (SELECT UserId FROM UserRegions WHERE RegionId IN (SELECT RegionId FROM UserRegions WHERE UserId == '{{userId}}'))",
      "accessType": "deny",
      "permissionsExcluded": [],
      "rolesExcluded": []
    },
    {
      "description": "Deny Holidays unless they are global or in a region associated with the user",
      "objectType": "Holidays",
      "filter": "Global == true OR UID IN (SELECT HolidayId FROM HolidayRegions WHERE RegionId IN (SELECT RegionId FROM UserRegions WHERE UserId == '{{userId}}'))",
      "accessType": "deny",
      "permissionsExcluded": [],
      "rolesExcluded": []
    },
    {
      "description": "Allow Contacts that do not have a region",
      "objectType": "Contacts",
      "filter": "RegionId == null",
      "accessType": "allow",
      "permissionsExcluded": [],
      "rolesExcluded": []
    },
    {
      "description": "Allow Jobs allocated to the current resource, whatever their region",
      "objectType": "Jobs",
      "filter": "UID IN (SELECT JobId FROM JobAllocations WHERE ResourceId == '{{resourceId}}' AND Status != 'Deleted' AND Status != 'Declined')",
      "accessType": "allow",
      "permissionsExcluded": [],
      "rolesExcluded": []
    }
  ]
}
```

Notes:
- The `Contacts` and `Jobs` allow rules widen the `hasLookup:Region` deny rule; the validator's
  "allow rule with no deny rule" warning is expected here because the deny comes from a pattern rule.
- The web app has no way to set a region on a Contact, hence the `RegionId == null` allow rule.
- The `Users` and `Holidays` rules here match on the user's `UserRegions` only; the platform template
  also matches the resource's primary and secondary regions there — reuse the `Regions` filter's
  three subqueries if resources carry the region assignments.
- The platform template also restricts `Activities` through the allocated resource's regions; add
  that rule if activities are in scope.

## Resource sees only their own work

```json
{
  "description": "Deny Jobs unless allocated to the current resource",
  "objectType": "Jobs",
  "filter": "UID IN (SELECT JobId FROM JobAllocations WHERE ResourceId == '{{resourceId}}' AND Status != 'Deleted' AND Status != 'Declined')",
  "accessType": "deny",
  "permissionsExcluded": [],
  "rolesExcluded": ["Scheduler"]
}
```

Add matching rules for `Shifts` (`ResourceShifts`), `Activities` (`ResourceId == '{{resourceId}}'`),
and `Resources` (`UID == '{{resourceId}}'`) as needed. Exclude every office role, or the schedulers
lose the jobs they are meant to dispatch.

## Ownership through a custom user-details object

A common customer pattern: a custom object maps each user to the accounts they may see.

```json
{
  "description": "Deny Accounts unless linked to the user in CustomUserDetails",
  "objectType": "Accounts",
  "filter": "UID IN (SELECT AccountId FROM CustomUserDetails WHERE UserId == '{{userId}}')",
  "accessType": "deny",
  "permissionsExcluded": [],
  "rolesExcluded": ["Scheduler"]
}
```

Repeat for objects linked to accounts (`AccountId IN (SELECT AccountId FROM CustomUserDetails WHERE
UserId == '{{userId}}')` on `Jobs`, `Contacts`, …), or use `hasLookup:Account`.

## Exclusions packages and integrations need

- **Installed packages with their own role** must be excluded wherever they read data. For example,
  the booking wizard's `booking-site-settings` role needs excluding on `Regions`, `Resources`,
  `Jobs`, `Accounts`, `Contacts`, and `Users`, including `hasLookup` rules.
- **Integration and connected-function users** see what their token's user sees. Exclude their role,
  or give the user `skedulo.tenant.data.viewAll` + `skedulo.tenant.data.modifyAll`.
- **Webhooks and triggered actions** run as an admin API user and are not filtered by RAP.

## Things that look right but are wrong

- `"accessType": "deny", "filter": "Status == 'Archived'"` described as "deny archived jobs" — a deny
  rule *keeps* what matches, so this hides every job that is not archived. Write
  `Status != 'Archived'` instead.
- `Resource.Name == '...'` or `Job.Region.Name` — bound lookups are rejected; use subqueries.
- `'{{currentUser}}'`, `'{{regionId}}'` — not placeholders; rejected.
- Excluding `Administrator` — rejected, and unnecessary.
- Time-based filters with `NOW()` parse, but the user guide lists date/time filters as unsupported
  and subscriptions keep stale rules; avoid them unless verified on the tenant.

## Performance

Every rule becomes part of every query on its object. Prefer one indexed subquery over nested
subqueries, keep pattern rules few, and re-test list views and the mobile agenda on realistic data
volumes before enabling in production.
