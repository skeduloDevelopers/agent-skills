# Skedulo Pulse Object Models

Define, edit, review, and deploy Skedulo Pulse object models — custom objects, custom fields on standard objects, lookups, picklists, and constraint-based validation.

## Use this skill when

- Modelling a new custom object or adding custom fields to a standard object
- Defining lookups (many-to-one) or HasMany (one-to-many) relationships
- Setting field constraints (`required`, `unique`, `maxLength`, `defaults`) or picklist values
- Reviewing a state file before `sked artifacts ... upsert`
- Mapping a requirement to an existing standard object before proposing a custom one

## Key rules

- Always check for an existing standard object before authoring a custom one
- Custom objects: PascalCase and plural; no `sked_` prefix, no `_c` / `__c` suffix
- `required: true` on a non-Lookup field needs a present, non-blank `defaults.defaultValue`
- HasMany is an explicit state file on the parent — it does not auto-appear from a child Lookup
- Cross-field / server-side validation uses Triggered Actions, not a validation artifact

## Example

```json
{
  "objectName": "Jobs",
  "name": "InspectionScore",
  "type": "Int",
  "constraints": { "required": false, "unique": false }
}
```
