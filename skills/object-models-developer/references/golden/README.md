# Golden custom-field state files

One complete state file per authorable field type. Copy the one for your type, then change
`objectName`, `name`, `display.label` and the values. Never take the key set from a ticket's or
sub-issue's JSON example — those are often partial.

| File | Type |
|---|---|
| `String.custom-field.json` | String |
| `TextArea.custom-field.json` | TextArea (`maxLength: 4000` is an example; omitted, the platform defaults to 255) |
| `URL.custom-field.json` | URL |
| `Int.custom-field.json` | Int |
| `Decimal.custom-field.json` | Decimal |
| `Boolean.custom-field.json` | Boolean |
| `Date.custom-field.json` | Date |
| `Datetime.custom-field.json` | Datetime |
| `Time.custom-field.json` | Time |
| `Picklist.custom-field.json` | Picklist, single-select (`multipleAllowed: false`) |
| `MultiPicklist.custom-field.json` | Picklist, multi-select (`multipleAllowed: true`) |
| `Lookup.custom-field.json` | Lookup |
| `HasMany.custom-field.json` | HasMany (no `constraints` block) |

## Provenance

Each file is the output of `sked artifacts custom-field get` for a field upserted to a test
tenant, with the object and field renamed to neutral `DemoObjects` names and the key set kept
as `get` returned it. `maxLength` is explicit on String, URL and TextArea, and `unique: false`
on String, URL, Int and Decimal. Optional keys such as `constraints.defaults` appear only where
the type requires them (Boolean); add one when the field needs an insert default.

`scripts/validate_object_models.py` loads these files and errors on any key in `field`,
`field.constraints` or `field.display` that an authored field of the same type leaves out.
Editing a golden changes what the validator requires.

## Refreshing

1. Upsert one field per type to a scratch custom object on a non-production tenant.
2. Retrieve each with
   `sked artifacts custom-field get -a <alias> --objectName <Object> --name <Field> -o <dir>`.
3. Rename the object and field to the neutral names above and keep every key `get` returned.
4. Run `python3 -m pytest object-models/scripts -q` — every golden must validate clean.
5. Delete the scratch object.
