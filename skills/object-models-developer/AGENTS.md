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
- Start every custom field from `references/golden/<Type>.custom-field.json` and keep every key it carries; a ticket's JSON example supplies values, never the key set
- Always set `maxLength` on String, URL and TextArea — omitted, all three default to 255
- Custom objects: PascalCase and plural; no `sked_` prefix, no `_c` / `__c` suffix
- `required: true` on a non-Lookup field needs a present, non-blank `defaults.defaultValue`
- `field.type`, `field.multipleAllowed` and every `field.constraints` key (incl. `maxLength`, `required`, `unique`) are read-only once deployed — never add, remove, or change them on an existing field (writing out an omitted key's platform value, `maxLength: 255` or `unique: false`, is allowed)
- Picklist `defaults.defaultValue` is the insert default; the `default: true` entry is the form pre-fill — they may differ
- HasMany is an explicit state file on the parent — it does not auto-appear from a child Lookup
- Cross-field / server-side validation uses Triggered Actions, not a validation artifact

## Example

`custom-fields/Jobs/Jobs-InspectionScore.custom-field.json`, copied from `references/golden/Int.custom-field.json`:

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "InspectionScore",
  "field": {
    "type": "Int",
    "description": "",
    "display": { "label": "Inspection Score", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": false, "accessMode": "ReadWrite" }
  }
}
```
