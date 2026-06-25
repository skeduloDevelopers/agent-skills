---
name: object-models-developer
description: This skill enables Claude to define, edit, review, and deploy Skedulo Pulse object models — custom objects, custom fields on standard objects, lookups, picklists, and constraint-based validation rules. Object-model work sits on the critical path of every Pulse implementation, so getting the state-file shape right is foundational.
---

# Skedulo Pulse Object Models Skill

## What is the Object Model in Pulse?

The Skedulo Pulse data model is composed of:

- **Standard objects** (`Jobs`, `Resources`, `Accounts`, `Contacts`, `JobAllocations`, `Shifts`, `Activities`, `Availability`, `Regions`, `Users`, `Locations`, etc.) — these come built-in with Pulse and cannot be deleted. They CAN be extended with custom fields.
- **Custom objects** — defined per-tenant. Typical examples: `AccountNotes`, `Inspections`, `SignOffForms`. Convention: **PascalCase _and_ plural**, mirroring the built-in standard objects above (`Jobs`, `Accounts`, `Resources`). Do NOT prefix custom object names with `sked_` (that namespace belongs to Skedulo's own platform objects) and do NOT add a Salesforce-style `_c`/`__c` suffix.
- **Custom fields** — attached to either a custom object or a standard object. 13 authorable field types (see "The 13 Field Types" below for state-file shape, or load [`references/field-types.md`](references/field-types.md) for a what / when-to-use / wire-type / gotchas quick reference per type).
- **Lookups (many-to-one, child side)** — a special field type that references another object. Implemented as a single `Lookup` field state file with `relationship.targetObjectName`; Pulse automatically exposes both the lookup object (`Account`) and the scalar ID (`AccountId`) at the GraphQL layer.
- **HasMany (one-to-many, parent side)** — the reverse-relationship field that exposes the child collection on the parent (e.g. `Account.Notes`, `DemoObject.DemoChildObjects`). This is its own authorable state file on the parent — it does NOT auto-appear just because a child has a Lookup. It must be created explicitly via `sked artifacts custom-field upsert` against the parent object, and it binds to a specific Lookup field on the child via `relationship.targetObjectIdFieldName`.
- **Validation** — Pulse has no separate `validation-rule` artifact. Validation is expressed declaratively as field constraints (`required`, `unique`, `maxLength`, `precision`/`scale`, `defaults`, `display.showIf`, `accessMode`). Cross-field server-side rules use Triggered Actions instead.

This skill teaches the canonical shape of every state file so you write JSON the `sked artifacts ... upsert` CLI will accept on the first try.

## References (load on demand)

Two reference files live alongside this SKILL.md under `references/`. **Do not load them by default.** Read them only when the conversation surfaces one of the explicit triggers below — they are sizeable (435 + 1,490 lines) and would consume context unnecessarily if loaded for every task.

| Reference | Read when the user / task mentions… |
|---|---|
| [`references/field-types.md`](references/field-types.md) | A specific field type (`Lookup`, `HasMany`, `Picklist`, `Decimal`, `URL`, `Geolocation`, `StandardPicklist`, etc.); choosing between two types ("Int or Decimal?", "Picklist or Boolean?"); a field-type concept (precision/scale, multi-select, GraphQL wire type, picklist immutability, picklist dependencies, `unique: true` for upsert); or any retrieve-flow output showing `field.type: "..."` the agent doesn't recognise. |
| [`references/standard-objects.md`](references/standard-objects.md) | A specific standard object by name (any of the 49 — `Jobs`, `Resources`, `JobAllocations`, `Tags`, `Regions`, `Availabilities`, `ResourceJobOffers`, `ShiftOffers`, `Accounts`, `Contacts`, `Activities`, `Holidays`, `Users`, etc.); a requirement entity that might map to a standard object before any custom-object proposal (always check first); a junction-table pattern (Tags / Regions / Resources joins); a parent/child relationship question; an immutable-platform-picklist suspicion. |

**How to load:** when a trigger fires, read the relevant reference file with the Read tool, then continue. After loading, cite the section you used (e.g. "per `references/field-types.md` § HasMany") so the user can trace the rule.

**Standard-object reuse check is mandatory** before proposing any new custom object. If a requirement entity might map to a standard object — even at low confidence — load `references/standard-objects.md` and verify before authoring a custom-object state file.

## CLI Surface

```bash
# Object CRUD
sked artifacts custom-object list   -a <alias>
sked artifacts custom-object get    -a <alias> --name <ObjectName> -o <outputdir>
sked artifacts custom-object upsert -a <alias> -f <state-file>
sked artifacts custom-object delete -a <alias> --name <ObjectName>

# Field CRUD
sked artifacts custom-field list   -a <alias> --objectName <ObjectName>
sked artifacts custom-field get    -a <alias> --objectName <ObjectName> --name <FieldName> -o <outputdir>
sked artifacts custom-field upsert -a <alias> -f <state-file>
sked artifacts custom-field delete -a <alias> --objectName <ObjectName> --name <FieldName>
```

The `-a <alias>` flag is the tenant alias from `sked tenant list`. **Always require the user to pass the alias explicitly** — never default silently.

## Workspace Layout (in the consuming project)

```text
<project>/                                                 # sked package root
├── SPEC.md                                                # data-model spec, feature checklist
├── custom-objects/
│   └── <ObjectName>.custom-object.json
└── custom-fields/
    └── <ObjectName>-<FieldName>.custom-field.json
```

`custom-objects/` and `custom-fields/` sit directly at the project root — no `src/` wrapper. This matches the canonical `sked` package layout, so the project root IS a valid `sked` package directory and can be deployed as a whole via `sked package deploy local -p .` in addition to the per-artifact `sked artifacts ... upsert` flow.

The file-name convention mirrors what `sked artifacts ... get` emits, so files round-trip cleanly between tenant and local.

---

## Custom Object State File

Minimal shape:

```json
{
  "metadata": { "type": "CustomObject" },
  "name": "DemoObject",
  "label": "Demo Object",
  "description": "Demo Object"
}
```

| Key | Required | Notes |
|---|---|---|
| `metadata.type` | yes | Must be exactly `"CustomObject"` |
| `name` | yes | **PascalCase _and_ plural** — match the platform's own standard objects (`Jobs`, `Accounts`, `Resources`, `JobAllocations`). No `sked_` prefix (that namespace is reserved for Skedulo platform objects) and no `_c`/`__c` suffix (that's a Salesforce convention, not Pulse). See "Naming guidance" below for the normalization recipe. |
| `label` | yes | Human-readable. Shown in Pulse Web admin and on Platform Pages. |
| `description` | yes (may be `""`) | Visible to admins; describes the object's purpose. |

**MANDATORY: every custom object also requires a custom `Name` field.**

`Name` is the natural key for the object and is the value the platform displays in record lists, lookup pickers, and breadcrumbs. **An object without a `Name` field cannot be the target of a `Lookup Relationship`** — any custom-field state file that tries to Lookup this object will fail to bind at deploy time. `Name` is NOT auto-created by `sked artifacts custom-object upsert`; you author it as a separate custom-field state file alongside the custom-object state file.

**File:** `custom-fields/<ObjectName>-Name.custom-field.json`

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "<ObjectName>",
  "name": "Name",
  "field": {
    "type": "String",
    "description": "Display name for this record",
    "display": { "label": "Name", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": true },
    "constraints": { "required": true, "unique": false, "accessMode": "ReadWrite", "maxLength": 255,
                     "defaults": { "defaultValue": "Untitled" } }
  }
}
```

**Pulse does NOT support auto-increment for `Name`.** The caller must supply a value at insert (or rely on the `defaults.defaultValue` you set). If you need a deterministic identifier like `VAC-0001`, generate it in a Triggered Action or upstream integration code — do not expect the platform to fill it.

**Naming guidance — objects are PascalCase AND plural:**

A custom object `name` must be **PascalCase and plural**, mirroring how every built-in Pulse object is named (`Jobs`, `Accounts`, `Resources`, `JobAllocations`, `Shifts`). The GraphQL collection then reads naturally (`accountNotes { … }`), and the auto-generated Platform Pages / related-lists pluralise correctly.

**Never copy the requirement's wording verbatim.** Requirements arrive as free text ("a schedule plan", "scheduleplan", "schedule_plan"). Normalize before writing the file:

1. Take the entity's noun phrase from the requirement.
2. Split into words; PascalCase each word (capitalise the first letter, drop spaces / underscores / hyphens).
3. Pluralise the head (last) noun.
4. Do not add a `sked_` prefix or a `_c`/`__c` suffix.

| Requirement says… | ❌ wrong (verbatim / singular / prefixed) | ✅ correct |
|---|---|---|
| "schedule plan" | `scheduleplan`, `SchedulePlan` | `SchedulePlans` |
| "site inspection" | `site_inspection`, `SiteInspection` | `SiteInspections` |
| "account note" | `sked_AccountNote`, `accountnote` | `AccountNotes` |

The state file is named after the final value: object `SchedulePlans` → `custom-objects/SchedulePlans.custom-object.json`.

- **Do NOT use** `SchedulePlan__c` (SF suffix), `scheduleplan` / `schedule_plan` (lowercase / snake_case), a singular `SchedulePlan`, or a `sked_`-prefixed name — each either fails the review or creates downstream friction.
- **Custom fields follow the same casing rule** — field `name` is PascalCase too (`Notes`, `IsAlert`, `ResolvedAt`), normalized the same way from the requirement. Fields are NOT pluralised (they name a single attribute), with one exception: a `HasMany` collection field is a plural noun for the children it exposes (`Notes`, `Inspections`).
- **The standard-object parent of an overlay field follows it too.** When a custom field is added to a standard object, the `objectName` and the file-name prefix are the fixed canonical PascalCase-plural identifier of that standard object (`Jobs`, `Resources`, `Accounts`, `JobAllocations`) — taken from `references/standard-objects.md` / GraphQL introspection / `sked artifacts custom-field get` output, **never** the requirement's casing. A requirement that says "fields on the jobs object" still yields `objectName: "Jobs"` and `custom-fields/Jobs-Event.custom-field.json` — `jobs` / `jobs-Event.custom-field.json` is wrong.
- **One exception to the plural rule — Skedulo-for-Salesforce:** when a Pulse object name is dictated by an existing Salesforce object, the connector derives the Pulse name from the SF API name rather than this convention (see the "Skedulo for Salesforce note" section). That applies ONLY to SF-mastered objects; objects you author greenfield in Pulse are always plain PascalCase plural.

---

## Custom Field State File — Shared Skeleton

Every custom field shares this skeleton:

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "<ParentObjectName>",
  "name": "<FieldName>",
  "field": {
    "type": "<FieldType>",
    "description": "",
    "display": {
      "label": "<Field Label>",
      "order": 0,
      "isAlert": false,
      "showIf": null,
      "showOnDesktop": false,
      "showOnMobile": false,
      "editableOnMobile": false,
      "requiredOnMobile": false
    },
    "constraints": {
      "required": false,
      "accessMode": "ReadWrite"
    }
  }
}
```

Then layer per-type extras into `field.constraints`, `field.relationship`, or `field.allowedValues` as appropriate.

### `display` block

| Key | Type | Default | Notes |
|---|---|---|---|
| `label` | string | required | Human-readable label shown in UI |
| `order` | int | 0 | Display order; lower = earlier. Use for layout control. |
| `isAlert` | bool | false | When true, the field renders with alert styling in the UI |
| `showIf` | string\|null | null | Boolean expression to conditionally show the field (see below) |
| `showOnDesktop` | bool | false | Whether the field appears on Pulse Web record pages by default |
| `showOnMobile` | bool | false | Whether the field appears in Skedulo Plus mobile by default |
| `editableOnMobile` | bool | false | Whether mobile users can edit the field |
| `requiredOnMobile` | bool | false | Whether mobile users must fill the field |

**`showIf` syntax**: a string expression evaluated against the record. Supports `==`, `!=`, `&&`, `||`, parentheses, string and boolean literals.

Examples:
- `"IsAlert == true"`
- `"Priority == 'High' || Priority == 'Critical'"`
- `"Status != 'Resolved'"`

Always make sure referenced field names exist on the same object.

### `constraints` block

Shared keys (all types):

| Key | Type | Default | Notes |
|---|---|---|---|
| `required` | bool | false | Whether the field is mandatory at insert/update |
| `accessMode` | string | `"ReadWrite"` | One of: `"ReadWrite"`, `"ReadOnly"`. `ReadOnly` makes the field non-editable via UI/API. |
| `defaults.defaultValue` | varies | none | Server-side default at insert. Type must match `field.type`. |

Type-specific keys (only valid on the types listed):

| Key | Valid on | Type | Notes |
|---|---|---|---|
| `unique` | String, Int, Decimal | bool | Enforces uniqueness across records on this object |
| `maxLength` | String, TextArea, URL | int | Max characters. Defaults: String=255, TextArea=32,000, URL=255. TextArea's hard platform cap is **131,072** chars — raise above the default explicitly when you know your data exceeds 32K. |
| `precision` | Decimal | int | Total digits including decimals. Common: 10. |
| `scale` | Decimal | int | Digits after decimal. Must be `<= precision`. Common: 2. |

**Coherence rules** (the review agent enforces these):
- **`required: true` on any non-`Lookup`, non-`HasMany` field MUST have a `defaults.defaultValue` that is present AND non-blank.** Pulse rejects required-without-default at upsert (`"Column <field> must have a default value in order to be added to an existing table"`), and a blank default (`""` on a text field) does not satisfy `required` — so an empty string is NOT a valid default for a required field. For a single-select `Picklist`, the default MUST equal the `value` of the `allowedValues` entry marked `default: true` (and a required single-select picklist MUST mark exactly one such entry). `Boolean`/`Int`/`Decimal`/`Date`/`Datetime`/`Time` literals are inherently non-blank. `Lookup` is the documented exception — there is no meaningful default for an ID reference, so keep Lookups `required: false` and enforce required-ness via a Triggered Action if the business needs it; `HasMany` has no `constraints` block at all.
- `required: true` + `accessMode: "ReadOnly"` is incoherent UNLESS `defaults.defaultValue` is set — otherwise no caller can supply the value at insert and the insert always fails.
- `unique` MUST be present as a boolean on every String / Int / Decimal field — set `false` when the field is not a natural key, not omitted. Pulse rejects a missing key on these types with `[Bad Request] field.constraints.unique must be a boolean value`. (All the examples below carry `"unique": false` for this reason.)
- `unique: true` on non-uniquable types (Boolean / Date / Datetime / Time / Picklist / Lookup / TextArea / URL) is rejected by Pulse.
- `maxLength` on a non-text type is ignored at best, rejected at worst.
- `defaults.defaultValue` type must match `field.type` exactly:
  - `Boolean` → `true` / `false`
  - `Int` → integer literal
  - `Decimal` → number literal
  - `String` / `TextArea` / `URL` → string
  - `Date` → ISO date string (`"2026-05-22"`)
  - `Datetime` → ISO datetime string (`"2026-05-22T12:00:00Z"`)
  - `Time` → `"HH:MM"` or `"HH:MM:SS"`
  - `Picklist` (single) → string matching one of `allowedValues[].value`

---

## The 13 Field Types (+ 2 special)

> The 13 entries below are the authorable custom-field types. Two additional types appear when retrieving existing platform state files but cannot be authored from scratch:
>
> - **`Geolocation`** — only present on standard objects (e.g. `Jobs.GeoLocation`, `Resources.GeoLocation`); custom `Geolocation` fields are rejected by the platform. Query via the companion `GeoLatitude` / `GeoLongitude` fields. See [`references/field-types.md`](references/field-types.md) §14.
> - **`StandardPicklist`** — the round-trip type that `sked artifacts custom-field get` emits when retrieving values on an existing standard-object picklist (e.g. `Jobs.AbortReason`). Preserve `field.type: "StandardPicklist"` exactly when round-tripping; do not coerce to `Picklist` or the upsert is rejected. See [`references/field-types.md`](references/field-types.md) §15.

> **Note on example object names.** `DemoObject` / `DemoChildObject` below are Skedulo's pre-existing demo-tenant objects used purely to illustrate field shape — they are NOT a naming exemplar. When you author a new custom object, always apply the **PascalCase + plural** rule above (`AccountNotes`, `SchedulePlans`), never a singular name.


### 1. String — short text

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "DemoObject",
  "name": "FieldText",
  "field": {
    "type": "String",
    "description": "",
    "display": { "label": "Field Text", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": false, "accessMode": "ReadWrite", "maxLength": 255 }
  }
}
```

Notes:
- Default `maxLength` is 255. Raise to e.g. 1000 if needed, but consider TextArea for >500 chars.
- `unique: true` is valid here for natural-key-style fields (e.g. `ExternalId`).

### 2. TextArea — long text

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "Notes",
  "field": {
    "type": "TextArea",
    "description": "",
    "display": { "label": "Notes", "order": 1, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": false },
    "constraints": { "required": false, "accessMode": "ReadWrite", "maxLength": 32000 }
  }
}
```

Notes:
- Default `maxLength` is 32,000 — the platform-API default. The hard platform cap is **131,072** characters; set `maxLength` above 32,000 explicitly when you know your data exceeds it. Lower it to enforce shorter notes (e.g. 8000 for tweet-sized).
- TextArea cannot be unique.

### 3. URL — URL with format validation

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "DemoObject",
  "name": "FieldURL",
  "field": {
    "type": "URL",
    "description": "",
    "display": { "label": "Field URL", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": false, "accessMode": "ReadWrite", "maxLength": 255 }
  }
}
```

Notes:
- Pulse validates URL format at insert.
- `maxLength` default 255, raise for long signed URLs.

### 4. Int — whole numbers

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "RetryCount",
  "field": {
    "type": "Int",
    "description": "",
    "display": { "label": "Retry Count", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": false, "accessMode": "ReadWrite",
                     "defaults": { "defaultValue": 0 } }
  }
}
```

Notes:
- 64-bit signed integer at the wire level.
- `unique: true` works (rare in practice).

### 5. Decimal — fixed-point number

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "EstimatedCost",
  "field": {
    "type": "Decimal",
    "description": "",
    "display": { "label": "Estimated Cost", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": false, "accessMode": "ReadWrite",
                     "precision": 10, "scale": 2 }
  }
}
```

Notes:
- `precision >= scale` always. Common: precision 10 / scale 2 = max 99,999,999.99.
- For currency, scale 2 is conventional; for distances / weights, scale 3 or 4.

### 6. Boolean — checkbox

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "IsAlert",
  "field": {
    "type": "Boolean",
    "description": "",
    "display": { "label": "Alert?", "order": 2, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": false },
    "constraints": { "required": true, "accessMode": "ReadWrite",
                     "defaults": { "defaultValue": false } }
  }
}
```

Notes:
- Booleans are typically `required: true` with `defaults.defaultValue` set (so callers don't need to supply it but the field is always known to be true or false on disk).

### 7. Date — calendar date

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "ContractEndDate",
  "field": {
    "type": "Date",
    "description": "",
    "display": { "label": "Contract End Date", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "accessMode": "ReadWrite" }
  }
}
```

### 8. Datetime — timestamp (UTC at the wire)

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "ResolvedAt",
  "field": {
    "type": "Datetime",
    "description": "",
    "display": { "label": "Resolved At", "order": 0, "isAlert": false,
                 "showIf": "IsAlert == true",
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "accessMode": "ReadWrite" }
  }
}
```

Notes:
- Stored / transmitted as UTC. UI displays in user's timezone.
- Excellent candidate for `showIf` (e.g. only show "resolved at" when "is alert" is true).

### 9. Time — time-of-day

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "PreferredArrivalTime",
  "field": {
    "type": "Time",
    "description": "",
    "display": { "label": "Preferred Arrival Time", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": false },
    "constraints": { "required": false, "accessMode": "ReadWrite" }
  }
}
```

Notes:
- `"HH:MM"` or `"HH:MM:SS"` format. No timezone — wall-clock time.

### 10. Picklist (single-select)

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "Status",
  "field": {
    "type": "Picklist",
    "description": "",
    "display": { "label": "Status", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": true },
    "constraints": { "required": true, "accessMode": "ReadWrite",
                     "defaults": { "defaultValue": "Open" } },
    "multipleAllowed": false,
    "allowedValues": [
      { "value": "Open",       "label": "Open",       "active": true,  "default": true  },
      { "value": "InProgress", "label": "In Progress","active": true,  "default": false },
      { "value": "Resolved",   "label": "Resolved",   "active": true,  "default": false },
      { "value": "Cancelled",  "label": "Cancelled",  "active": false, "default": false }
    ]
  }
}
```

Notes:
- `multipleAllowed: false` flags single-select.
- `value` is the wire format; `label` is the UI display. Both required.
- `active: false` hides the value from new records but preserves it on existing records (soft-deprecation).
- At most one `default: true` for single-select picklists.
- If `required: true`, also set `constraints.defaults.defaultValue` to the `value` of the `default: true` entry (here `"Open"`) — the two must agree, and a required picklist with no default fails the upsert.
- Values must be unique within the field.

### 11. Picklist (multi-select)

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "DemoObject",
  "name": "FieldMultiPicklist",
  "field": {
    "type": "Picklist",
    "description": "",
    "display": { "label": "Field Multi Picklist", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "accessMode": "ReadWrite" },
    "multipleAllowed": true,
    "allowedValues": [
      { "value": "Value1", "label": "Value 1", "active": true, "default": false },
      { "value": "Value2", "label": "Value 2", "active": true, "default": false },
      { "value": "Value3", "label": "Value 3", "active": true, "default": false },
      { "value": "Value4", "label": "Value 4", "active": true, "default": false }
    ]
  }
}
```

Notes:
- `multipleAllowed: true` flags multi-select. Wire format is a JSON array of strings.
- Multiple `default: true` entries are allowed for multi-select.

### 12. Lookup — reference to another object

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "Account",
  "field": {
    "type": "Lookup",
    "description": "",
    "display": { "label": "Account", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": true, "accessMode": "ReadWrite" },
    "relationship": { "targetObjectName": "Accounts" }
  }
}
```

**Critical rules:**
- Write ONE field state file with `field.type: "Lookup"`. You do NOT need a separate `<Name>Id` file — Pulse exposes both surfaces (`Account` object + `AccountId` scalar) at the GraphQL layer automatically.
- `relationship.targetObjectName` MUST be a valid object name in the same tenant: either another custom object in `custom-objects/`, or a standard Pulse object (Jobs, Resources, Accounts, Contacts, etc.).
- Lookup field name convention: singular noun of the target object (e.g. `Account` for `Accounts`). Reads naturally in code as `note.Account.Name`.
- A required lookup means the parent record cannot exist without a target. Use this carefully — it creates insert-order coupling.

### 13. HasMany — reverse collection on the parent

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "DemoObject",
  "name": "DemoChildObjects",
  "field": {
    "type": "HasMany",
    "description": "",
    "display": {
      "label": "Demo Child Object",
      "order": 0,
      "isAlert": false,
      "showIf": null,
      "showOnDesktop": true,
      "showOnMobile": false,
      "editableOnMobile": false,
      "requiredOnMobile": false
    },
    "relationship": {
      "targetObjectName": "DemoChildObject",
      "targetObjectIdFieldName": "FieldLookupDemoObjectId"
    }
  }
}
```

**Critical rules — read all of these before authoring a HasMany:**

- **HasMany is authored explicitly.** It does NOT auto-appear when a child has a Lookup back to this parent. To expose `Parent.Children` as a navigable collection, you must write a `<Parent>-<ChildrenName>.custom-field.json` state file and upsert it. (Skedulo's `sked artifacts custom-field list` will list it once created — confirming it's a real field, not a synthetic GraphQL projection.)
- **No `constraints` block.** Unlike all other field types, HasMany has NO `field.constraints`. There's no `required` / `unique` / `accessMode` — reverse collections are inherently read-only views of child rows. The CLI rejects HasMany state files that include `constraints`.
- **`relationship.targetObjectName`** is the child object name (the "many" side).
- **`relationship.targetObjectIdFieldName`** is the **scalar Id** of the Lookup field on the child that points back at this parent. If the child has a Lookup named `Owner` (with type `Lookup`, targeting this parent), the HasMany binds via `OwnerId` — the scalar ID surface that Pulse auto-derives from that Lookup. **The `Id` suffix is mandatory** — `FieldLookupDemoObject` (the lookup object) would NOT work; only `FieldLookupDemoObjectId` (the scalar) is accepted. (When authoring a HasMany via the Pulse Web UI instead of a state file, the same binding is expressed as picking the Lookup directly from a "Target field" dropdown — the UI hides the scalar-`Id` suffix and shows the Lookup field name; the state file is one level lower in the abstraction and requires the `Id` suffix explicitly.)
- **Dependency order at deploy:** the child object AND the child's Lookup field must both exist in the tenant BEFORE the HasMany state file is upserted. If you create them all in one project, deploy order is: parent custom-object → child custom-object → child Lookup field → parent HasMany field.
- **Naming convention:** HasMany name is conventionally the plural of the target object name (`DemoChildObjects`, `Notes`, `Inspections`). The `display.label` is what shows in the UI tab/list — Skedulo prefers the singular noun ("Demo Child Object", "Note", "Inspection") because the related-list UI says "Notes (5)" already, so doubling the plural is awkward.
- **Multiple HasMany pointing at the same child object** is supported when the child has multiple Lookups back. Each HasMany uses a different `targetObjectIdFieldName`. For example, an Account with two HasMany collections — `BillingNotes` (binding to `Notes.BillingAccountId`) and `ShippingNotes` (binding to `Notes.ShippingAccountId`) — both materialise as separate related-lists on the Account page.
- **`display.showIf`** works on HasMany the same as other fields — show the related-list only when a condition holds on the parent record.
- **No `editableOnMobile` semantics.** The flag exists in the state file (the CLI requires it for schema reasons), but HasMany is inherently read-only on mobile; setting `editableOnMobile: true` has no effect.

### Cardinality reminders

| Field type | Wire type | Nullable when not required |
|---|---|---|
| String / TextArea / URL | `String` | yes |
| Int | `Int` | yes |
| Decimal | `BigDecimal` | yes |
| Boolean | `Boolean!` (always present) | no — defaults to false or `defaults.defaultValue` |
| Date | `LocalDate` | yes |
| Datetime | `Instant` | yes |
| Time | `LocalTime` | yes |
| Picklist single | `String` | yes |
| Picklist multi | `[String!]` (list) | yes (null = empty list) |
| Lookup | `<TargetObject>` object + `<Name>Id: ID` scalar | yes |
| HasMany | `[<ChildObject>!]!` (non-null list, always present, empty list when no children) | n/a (always non-null) |

---

## Common Patterns

### Adding a custom field to a standard object

You only write the custom-field state file. The parent (Jobs / Resources / etc.) is platform-managed.

**Use the parent's canonical name, cased exactly.** The `objectName` and the file-name prefix are the standard object's canonical PascalCase-plural identifier (`Jobs`, `Resources`, `Accounts`) — exactly as the platform spells it. Do NOT lowercase, singularise, or copy the requirement's wording: a field `Event` on the Jobs object is `objectName: "Jobs"` in file `custom-fields/Jobs-Event.custom-field.json`, never `objectName: "jobs"` / `jobs-Event.custom-field.json`.

> **Terminology — "overlay."** Internally the platform refers to a custom field added to a standard object as a `DataSchemaFieldOverlay`, and a custom HasMany on a standard object as a `DataSchemaRelationshipOverlay`. You'll see these names surface in error codes (`DataSchemaFieldOverlayNotFound`, `DataSchemaFieldOverlayKeyAlreadyExists`, etc.) when the upsert fails. Treat them as a synonym for "the custom-field state file that extends a standard object."


```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Jobs",
  "name": "ExternalRef",
  "field": {
    "type": "String",
    "description": "Reference key from external system",
    "display": { "label": "External Ref", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": false, "unique": true, "accessMode": "ReadWrite", "maxLength": 255 }
  }
}
```

**Safety**: custom fields on standard objects are tenant-wide. Test in a non-prod tenant first.

### Audit timestamps on a custom object

Pulse auto-manages `UID`, `CreatedDate`, `LastModifiedDate`, `CreatedBy`, `LastModifiedBy`, `CreatedById`, `LastModifiedById`. Do NOT model these as custom fields. (`UID` is the primary key — Pulse generates it at insert and rejects any attempt to set it.) If you need a custom audit field (e.g. `ResolvedAt`), use type `Datetime`.

### Mutually visible fields (showIf pair)

To make `Resolution` visible only when `Status == 'Resolved'`:

```json
"display": { ..., "showIf": "Status == 'Resolved'" }
```

The condition fires client-side in the UI; it does NOT enforce the constraint server-side. For server-side cross-field validation, use a Triggered Action.

### Parent-with-children relationship (the full Lookup + HasMany pair)

To make `Account → Notes` navigable in BOTH directions (`note.Account.Name` and `account.Notes[]`), you need TWO custom-field state files plus the child object itself. Order matters at deploy time.

**Step 1 — Custom object for the child:**

**File:** `custom-objects/AccountNotes.custom-object.json`

```json
{
  "metadata": { "type": "CustomObject" },
  "name": "AccountNotes",
  "label": "Account Note",
  "description": "Notes attached to an Account"
}
```

**Step 2 — Mandatory `Name` field for the child** (without this, no other object can Lookup at `AccountNotes`):

**File:** `custom-fields/AccountNotes-Name.custom-field.json`

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "Name",
  "field": {
    "type": "String",
    "description": "Display name for this note",
    "display": { "label": "Name", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": true,
                 "editableOnMobile": true, "requiredOnMobile": true },
    "constraints": { "required": true, "unique": false, "accessMode": "ReadWrite", "maxLength": 255,
                     "defaults": { "defaultValue": "Note" } }
  }
}
```

**Step 3 — Lookup on the child (the "many → one" side):**

**File:** `custom-fields/AccountNotes-Account.custom-field.json`

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
  "name": "Account",
  "field": {
    "type": "Lookup",
    "description": "",
    "display": { "label": "Account", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "constraints": { "required": true, "accessMode": "ReadWrite" },
    "relationship": { "targetObjectName": "Accounts" }
  }
}
```

This auto-derives the scalar `AccountNotes.AccountId` at the GraphQL layer.

**Step 4 — HasMany on the parent (the "one → many" side):**

**File:** `custom-fields/Accounts-Notes.custom-field.json`

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "Accounts",
  "name": "Notes",
  "field": {
    "type": "HasMany",
    "description": "",
    "display": { "label": "Note", "order": 0, "isAlert": false, "showIf": null,
                 "showOnDesktop": true, "showOnMobile": false,
                 "editableOnMobile": false, "requiredOnMobile": false },
    "relationship": {
      "targetObjectName": "AccountNotes",
      "targetObjectIdFieldName": "AccountId"
    }
  }
}
```

`targetObjectIdFieldName: "AccountId"` is the scalar id surface from the child's `Account` Lookup field (Step 3). Note the singular `display.label` "Note" — the related-list UI already pluralises.

**Deploy order** (the `/deploy` command handles this for you):
1. `AccountNotes` custom-object (parent of the lookup)
2. `AccountNotes.Name` custom-field (mandatory natural key — without it, step 3's Lookup target is unusable)
3. `Accounts` standard object — no-op, already exists
4. `AccountNotes.Account` custom-field (child's Lookup)
5. `Accounts.Notes` custom-field (parent's HasMany)

Reverse the order and step 5 fails — the HasMany can't bind to a Lookup-scalar that doesn't exist yet. Skip step 2 and the child object cannot serve as a Lookup target at all.

### Soft-deprecating a picklist value

Don't delete the value (existing records still reference it). Instead, mark it inactive:

```json
{ "value": "OldStatus", "label": "Old Status (deprecated)", "active": false, "default": false }
```

New records cannot select it; existing records retain it.

### Decimal precision for money

Convention: precision 18, scale 2 for amounts that need to scale beyond 100M; precision 10, scale 2 for smaller amounts. Document the choice in SPEC.md Implementation Notes.

---

## Standard Objects (quick reference for lookup targets)

The full catalog of all 49 Skedulo Pulse standard objects — purpose, when to use, key fields, parents, children, and quirks — is at [`references/standard-objects.md`](references/standard-objects.md). **Load it whenever a standard object is mentioned by name** or when checking whether a requirement entity is already covered by the platform before proposing a custom object.

For Lookup target wiring, the common cluster is: `Accounts`, `Contacts`, `Jobs`, `JobAllocations`, `Resources`, `Shifts`, `Activities`, `Availabilities`, `Regions`, `Locations`, `Users`, `Tags`. The reference file groups all 49 objects into 7 functional clusters (Job lifecycle / Resource & availability / Offers & dispatch / Shifts & roster / Tagging / Regions & access / Account & contact) so you can scope quickly.

Always introspect via the graphql-schema MCP before assuming a target exists — Skedulo tenants can have configurable subsets enabled, and the reference is canonical at the platform level rather than per-tenant.

---

## Skedulo for Salesforce note

If the workspace is a **Skedulo for Salesforce** project (presence of `force-app/` + `sfdx-project.json`), Salesforce is the master data model. You do NOT create Pulse custom objects in that case — the SF object is created in `force-app/main/default/objects/`, then **registered** in Pulse via:

```text
Pulse Web → Settings → Data management → Custom fields → Select object → Add → register each field
```

**Three things engineers routinely miss on SF-master projects** — flag explicitly in SPEC.md and the deployment checklist:

1. **Registration is mandatory before GraphQL works.** Skedulo's connector does NOT auto-map SF objects/fields into the Pulse GraphQL schema — an admin must explicitly add each field via the Pulse Web UI. Until the field is registered, any Pulse-side Connected Function, Triggered Action, MEX form, Page Builder component, or GraphQL query that references it will fail with a "field not found" error.
2. **Registration is per-environment.** Registering a field in the sandbox tenant does NOT propagate to production — the admin must repeat the exact same `Settings → Data management → Custom fields → Add` flow in each Pulse environment (sandbox, UAT, production) after the SF object/field is deployed there. Plan this as a deployment-checklist row, not a one-time setup.
3. **Pulse-side GraphQL naming differs from SF API naming.** Once registered, the SF object `sked_AccountNote__c` exposes as Pulse GraphQL type `sked_AccountNote` (the `__c` suffix is dropped); SF field `Notes__c` exposes as `Notes`; SF `Id` exposes as Pulse `UID`. Confirm in the target sandbox before assuming — historical connector versions vary slightly.

**Determine the flavour before authoring.** If the project type is ambiguous, use `AskUserQuestion` at session start to confirm Pulse-standalone vs Skedulo-for-Salesforce. The init-agent's Step 0 standard-object reuse check + the rest of the workflow assume a Pulse-standalone tenant by default; for SF-master projects the data-model authoring happens in `force-app/main/default/objects/` and this plugin's role is to document + validate registration, not to produce `*.custom-object.json` deploy artifacts.

This plugin still applies for **Pulse-standalone tenants** and for documenting the SF-master baseline in `SPEC.md`. For SF-master projects, the JSON state files in `custom-fields/` mirror the registered SF fields for reference + GraphQL clarity, but don't get deployed via `sked artifacts upsert` — the SF deployment owns object/field creation.

The `/object-models:deploy` command detects this case (presence of `force-app/`) and emits a reminder so engineers don't accidentally deploy a Pulse-only schema that should live in Salesforce instead.

---

## Authoring Workflow Recap

1. **Reuse-check** every requirement entity against `references/standard-objects.md` before proposing any new custom object (the init-agent's Step 0 enforces this)
2. **Plan** the model (objects, fields, lookups, picklists, constraints) in SPEC.md before writing JSON
3. **Author** state files in `custom-objects/` and `custom-fields/` — and for every custom object, author its mandatory paired `<Object>-Name.custom-field.json`
4. **Validate** state-file schema (every file): `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_object_models.py" --workspace .` — deterministically rejects the structural defects the platform errors on (wrong `field.type`, missing `constraints.unique` / `display.isAlert` / `multipleAllowed`, plain-string `allowedValues`, `relationship.objectName` vs `targetObjectName`, HasMany with `constraints`, …) instead of letting them surface at deploy. Fix every reported error before reviewing. A `PostToolUse` hook also runs this on each Write/Edit, so issues surface as you author.
5. **Review** with `/object-models:review` (semantic + relational checks the validator can't make)
6. **Deploy** explicitly: `/object-models:deploy --alias <alias>`
7. **Verify** in Pulse Web → Settings → Data management

### After Deploy — Platform Pages auto-generate

Once a custom object lands in the tenant via `sked artifacts custom-object upsert`, Skedulo automatically generates four default Platform Pages for it: `-create`, `-edit`, `-view`, `-list`. The pages render using the field metadata from the custom-object + custom-field state files (display labels, order, showIf, etc.). No further action is required to get a working admin UI for the new object.

If you want a customised page (different field layout, a related-list of children, a custom action button), navigate to **Pulse Web → Settings → Developer tools → Platform pages** and **duplicate** the system-generated page. Editing the system-generated page directly is discouraged — duplicate first, then customise the copy. See the Skedulo platform docs (developer-guides / customize-and-extend / create-and-customize-pages) for the full Page Builder workflow.

Never auto-deploy from the coding agent. Never assume a tenant alias. Always introspect standard objects via MCP before adding custom fields to them.
