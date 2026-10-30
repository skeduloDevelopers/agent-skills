---
name: object-models-developer
description: Core skill for authoring, reviewing, and deploying Skedulo Pulse object models — custom objects, custom fields on standard objects, Lookup/HasMany relationships, picklists, and constraint-based validation rules. Covers the state-file JSON shapes, naming conventions, workspace layout, and sked CLI surface.
---

# Skedulo Pulse Object Models

The Pulse data model is composed of:

- **Standard objects** (`Jobs`, `Resources`, `Accounts`, `Contacts`, `JobAllocations`, `Shifts`, …) — built-in, cannot be deleted, CAN be extended with custom fields.
- **Custom objects** — defined per-tenant (`AccountNotes`, `Inspections`, `SchedulePlans`).
- **Custom fields** — attached to a custom or standard object. 13 authorable field types (+2 retrieve-only).
- **Lookups (many-to-one, child side)** — one `Lookup` state file with `relationship.targetObjectName`; Pulse auto-exposes both the lookup object (`Account`) and the scalar ID (`AccountId`) at the GraphQL layer.
- **HasMany (one-to-many, parent side)** — the reverse-collection field on the parent, authored as its own state file.
- **Validation** — Pulse has no separate `validation-rule` artifact. Validation is declarative field constraints (`required`, `unique`, `maxLength`, `precision`/`scale`, `defaults`, `display.showIf`, `accessMode`); cross-field server-side rules use Triggered Actions.

## Goal

Produce deploy-ready object-model artifacts: state files the `sked artifacts ... upsert` CLI
accepts on the first try, tracked in SPEC.md, passing
`scripts/validate_object_models.py --workspace .` with exit 0, and reviewed against
`references/review-checklist.md`.

## Guardrails

Platform rules you can't discover by reading the workspace — violations fail silently or at
deploy. The mechanically checkable subset is enforced by `scripts/validate_object_models.py`
(run it; a `PostToolUse` hook also lints every state file on Write/Edit); the rest you must hold:

- **Object names are PascalCase AND plural** (`SchedulePlans`, not `SchedulePlan` / `scheduleplan` / `schedule_plan`), mirroring the standard objects. No `sked_` prefix (reserved for Skedulo platform objects), no `_c`/`__c` suffix (Salesforce, not Pulse). Field names are PascalCase and NOT pluralised — except `HasMany` collection fields, which are plural. The standard-object parent of an overlay field uses its canonical PascalCase-plural identifier too: `objectName: "Jobs"` and `custom-fields/Jobs/Jobs-Event.custom-field.json`, never `jobs`/`jobs-Event`. Normalize the requirement's wording; never copy it verbatim. (Sole exception: Skedulo-for-Salesforce mirror objects — see that section.)
- **Every new custom object MUST also author its paired `Name` field** as a separate custom-field state file (`String`, `required: true`, `unique: false`, `maxLength` 255, non-blank default). `Name` is NOT auto-created by the object upsert, and Pulse has no auto-increment for it. Missing `Name` → the object silently cannot be the target of a Lookup: the upsert succeeds, but records display by `UID` only and any Lookup at the object fails to bind.
- **HasMany is authored explicitly** — it does NOT auto-appear when a child has a Lookup back. It has **NO `constraints` block** (the CLI rejects HasMany files that include one). `relationship.targetObjectIdFieldName` carries the **mandatory `Id` suffix** — it names the scalar Pulse derives from the child's Lookup (`AccountId` for a Lookup named `Account`); the bare Lookup name silently breaks the binding. Multiple HasMany to one child need distinct Lookups on the child (distinct `targetObjectIdFieldName`s). Deploy order: **parent object → child object → child Lookup → parent HasMany**.
- **`sked package deploy local --dryRun` passes a dangling Lookup target** — only `__type(name:"<Target>")` GraphQL introspection catches it (see `references/tenant-auth.md`). A Lookup target is valid only if it's a standard object, an in-package custom object, or already on the tenant.
- **Adding a `required` field to an existing object needs a non-blank default** — Pulse rejects it with `Column XYZ must have a default value in order to be added to an existing table`, and a blank `""` does not satisfy `required` either. Exception: `Lookup` has no meaningful default — keep Lookups `required: false` and enforce required-ness via a Triggered Action.
- **Field types are immutable after deploy** — changing `field.type` on an existing field is rejected (`field type cannot be changed`); the only path is delete + re-create, losing written data.
- **Five standard picklists are immutable**: `Jobs.JobStatus`, `Jobs.CustomerConfirmationStatus`, `Resources.Category`, `Activities.Type`, `Availabilities.Status` — they reject both CLI and REST modification. Other standard picklists round-trip via `field.type: "StandardPicklist"` (preserve that type exactly; coercing to `Picklist` is rejected); picklist-value dependencies need the Pulse-only `POST /custom/vocabulary/dependency/entry` REST endpoint.
- **Boolean fields must carry `defaults.defaultValue`** (`true`/`false`) — the CLI rejects Booleans without one.
- **TextArea `maxLength` defaults to 32,000; the hard platform cap is 131,072** — raise above the default explicitly when data exceeds 32K.
- **`precision >= scale` on Decimal**, always.
- **`constraints.unique` must be present as a boolean on every String / Int / Decimal field** — a missing key is rejected (`field.constraints.unique must be a boolean value`); set `false` unless the field is a natural key. `unique: true` on any other type is rejected.
- **A required single-select Picklist needs agreement**: `constraints.defaults.defaultValue` must equal the `value` of the exactly-one `allowedValues` entry marked `default: true`.

## References (load on demand)

| Reference | Read when… |
|---|---|
| [`references/field-types.md`](references/field-types.md) | Authoring any field — full state-file JSON example, wire type, constraints, and gotchas per type (all 13 authorable + `Geolocation` / `StandardPicklist` retrieve-only variants). |
| [`references/standard-objects.md`](references/standard-objects.md) | Any standard object is mentioned by name, or a requirement entity might map to a standard object — **always check before proposing a custom object**. Catalog of all 49, grouped into 7 functional clusters. |
| [`references/tenant-auth.md`](references/tenant-auth.md) | Any `sked` CLI call against a tenant — alias-or-token resolution (interactive vs headless), and the `__type` GraphQL introspection recipe for referential checks. |
| [`references/review-checklist.md`](references/review-checklist.md) | The review phase — semantic checks the validator can't make. |

## CLI Surface

```bash
# Object CRUD
sked artifacts custom-object list   -a <alias>
sked artifacts custom-object get    -a <alias> --name <ObjectName> -o <outputdir>
sked artifacts custom-object upsert -a <alias> -f <state-file>
sked artifacts custom-object delete -a <alias> --name <ObjectName>

# Field CRUD (--objectName is the parent object)
sked artifacts custom-field list   -a <alias> --objectName <ObjectName>
sked artifacts custom-field get    -a <alias> --objectName <ObjectName> --name <FieldName> -o <outputdir>
sked artifacts custom-field upsert -a <alias> -f <state-file>
sked artifacts custom-field delete -a <alias> --objectName <ObjectName> --name <FieldName>
```

`-a <alias>` is the tenant alias from `sked tenant list`. Never default it silently — resolve
auth per `references/tenant-auth.md`.

## Workspace Layout (in the consuming project)

```text
<project>/                                    # project root = sked package root (holds skeduloPackage.json)
├── skeduloPackage.json
├── SPEC.md                                   # data-model spec, feature checklist
└── src/object-model/
    ├── custom-objects/
    │   └── <ObjectName>.custom-object.json
    └── custom-fields/
        └── <ObjectName>/                     # one subdirectory per object
            └── <ObjectName>-<FieldName>.custom-field.json
```

This layout lets the whole project deploy via `sked package deploy local -p .`
from the root as well as per-artifact upserts. The `<ObjectName>-<FieldName>.custom-field.json`
naming mirrors what `sked artifacts ... get` emits, so files round-trip cleanly.

## Custom Object State File

```json
{
  "metadata": { "type": "CustomObject" },
  "name": "AccountNotes",
  "label": "Account Note",
  "description": "Notes attached to an Account"
}
```

All four keys are required (`description` may be `""`). The file is named after the `name`:
`src/object-model/custom-objects/AccountNotes.custom-object.json`.

**Its mandatory paired `Name` field** (see Guardrails) lives at
`src/object-model/custom-fields/<ObjectName>/<ObjectName>-Name.custom-field.json`:

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "AccountNotes",
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

If a deterministic identifier like `VAC-0001` is required, generate it in a Triggered Action or
upstream integration — the platform will not fill it.

## Custom Field State File — Shared Skeleton

Every custom field shares this skeleton, with per-type extras layered into `field.constraints`,
`field.relationship`, or `field.allowedValues`:

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

### `display` block

| Key | Type | Notes |
|---|---|---|
| `label` | string | Required — human-readable label shown in UI |
| `order` | int | Display order; lower = earlier |
| `isAlert` | bool | Renders with alert styling when true |
| `showIf` | string\|null | Conditional-display expression (see below) |
| `showOnDesktop` / `showOnMobile` | bool | Default visibility on Pulse Web / Skedulo Plus |
| `editableOnMobile` / `requiredOnMobile` | bool | Mobile edit/required flags |

`showIf` is a string expression evaluated against the record — supports `==`, `!=`, `&&`, `||`,
parentheses, string and boolean literals (e.g. `"Priority == 'High' || Priority == 'Critical'"`).
Referenced fields must exist on the same object. It fires client-side only — server-side
cross-field rules need a Triggered Action.

### `constraints` block

| Key | Valid on | Notes |
|---|---|---|
| `required` | all except HasMany | Mandatory at insert/update — see Guardrails for the default requirement |
| `accessMode` | all except HasMany | `"ReadWrite"` or `"ReadOnly"`. `required: true` + `ReadOnly` needs a `defaults.defaultValue` or inserts are impossible |
| `defaults.defaultValue` | scalar types | Server-side default at insert; type must match `field.type` exactly (`Boolean` → bool, `Int` → integer, `Decimal` → number, text types → string, `Date` → `"2026-05-22"`, `Datetime` → `"2026-05-22T12:00:00Z"`, `Time` → `"HH:MM[:SS]"`, single Picklist → an `allowedValues[].value`) |
| `unique` | String, Int, Decimal | Mandatory boolean on these types (see Guardrails) |
| `maxLength` | String, TextArea, URL | Defaults: String 255, TextArea 32,000 (cap 131,072), URL 255 |
| `precision` / `scale` | Decimal | Total digits / digits after decimal; `precision >= scale` |

## The 13 Field Types (+2 retrieve-only)

| Type | Wire type | Typical use / key extras |
|---|---|---|
| String | `String` | Short text; `maxLength` default 255 |
| TextArea | `TextArea` | Long text; default 32,000, hard cap 131,072; never unique |
| URL | `URL` | Format-validated at insert |
| Int | `Int` | 64-bit signed integer |
| Decimal | `BigDecimal` | `precision` + `scale` (money: 10/2 or 18/2) |
| Boolean | `Boolean!` | Always on the wire; default mandatory |
| Date | `LocalDate` | Calendar date |
| Datetime | `Instant` | UTC on the wire; UI renders user timezone |
| Time | `LocalTime` | Wall-clock, no timezone |
| Picklist (single) | `String` | `multipleAllowed: false` + `allowedValues` (`value`/`label`/`active`/`default` per entry; soft-deprecate with `active: false`) |
| Picklist (multi) | `[String!]` | `multipleAllowed: true`; multiple defaults allowed |
| Lookup | object + `<Name>Id: ID` scalar | `relationship.targetObjectName`; name it the singular of the target (`Account` → `Accounts`) |
| HasMany | `[<Child>!]!` | `relationship.targetObjectName` + `targetObjectIdFieldName`; NO `constraints`; name plural, `display.label` singular (the related-list UI already pluralises) |
| Geolocation *(retrieve-only)* | — | Standard objects only; custom `Geolocation` is rejected — use two `Decimal` fields; query via `GeoLatitude`/`GeoLongitude` |
| StandardPicklist *(retrieve-only)* | `String` | Emitted by `get` on an existing standard-object picklist; preserve the type exactly on round-trip |

Full state-file JSON examples, per-type constraints, and gotchas for every type live in
[`references/field-types.md`](references/field-types.md) — read the relevant section before
authoring a field type for the first time in a session.

## Common Patterns

### Custom field on a standard object ("overlay")

You only write the custom-field state file — the parent (`Jobs`, `Resources`, …) is
platform-managed. Internally the platform calls this a `DataSchemaFieldOverlay` (HasMany:
`DataSchemaRelationshipOverlay`) — those names surface in deploy error codes (see
`commands/deploy.md` Step 6b for the fix crib). Overlays are tenant-wide: test in a non-prod
tenant first.

### Audit timestamps

Pulse auto-manages `UID` (primary key — never settable), `CreatedDate`, `LastModifiedDate`,
`CreatedBy`/`CreatedById`, `LastModifiedBy`/`LastModifiedById`. Do NOT model these as custom
fields; custom audit needs (e.g. `ResolvedAt`) use a `Datetime` field.

### Parent-with-children (the full Lookup + HasMany pair)

To make `Account → Notes` navigable both ways (`note.Account.Name` and `account.Notes[]`),
author FOUR state files, deployed in this order:

1. `custom-objects/AccountNotes.custom-object.json` — the child object
2. `custom-fields/AccountNotes/AccountNotes-Name.custom-field.json` — mandatory natural key (without it, step 3's Lookup target is unusable)
3. `custom-fields/AccountNotes/AccountNotes-Account.custom-field.json` — Lookup → `Accounts` (auto-derives the `AccountId` scalar)
4. `custom-fields/Accounts/Accounts-Notes.custom-field.json` — HasMany → `AccountNotes` with `targetObjectIdFieldName: "AccountId"`

Reverse the order and step 4 fails — the HasMany can't bind to a Lookup scalar that doesn't
exist yet. Per-shape JSON for steps 3–4 is in `references/field-types.md` §12–13.

### Money

Decimal precision 18 / scale 2 for amounts beyond 100M; 10 / 2 otherwise. Document the choice in
SPEC.md Implementation Notes.

## Skedulo for Salesforce note

If the workspace is a **Skedulo for Salesforce** project (presence of `force-app/` +
`sfdx-project.json`), Salesforce is the master data model. You do NOT create Pulse custom
objects — the SF object is created in `force-app/main/default/objects/`, then **registered** in
Pulse via:

```text
Pulse Web → Settings → Data management → Custom fields → Select object → Add → register each field
```

Three things engineers routinely miss on SF-master projects — flag them in SPEC.md and the
deployment checklist:

1. **Registration is mandatory before GraphQL works.** The connector does NOT auto-map SF objects/fields into the Pulse GraphQL schema — until a field is registered, any Pulse-side Connected Function, Triggered Action, MEX form, or GraphQL query referencing it fails with "field not found".
2. **Registration is per-environment.** Registering in sandbox does NOT propagate — repeat the flow in each Pulse environment (sandbox, UAT, production). Plan it as a deployment-checklist row.
3. **Pulse GraphQL naming differs from SF API naming.** `sked_AccountNote__c` exposes as `sked_AccountNote` (the `__c` drops); `Notes__c` → `Notes`; SF `Id` → Pulse `UID`. Confirm in the target sandbox — connector versions vary.

Determine the flavour before authoring — if ambiguous, ask via `AskUserQuestion` at session
start. For SF-master projects, JSON state files may mirror the registered SF fields for
reference, but they don't get deployed via `sked artifacts upsert`; `/object-models:deploy`
detects `force-app/` and emits a registration reminder.

## Authoring Workflow Recap

1. **Reuse-check** every requirement entity against `references/standard-objects.md` before proposing any custom object
2. **Plan** the model (objects, fields, lookups, picklists, constraints) in SPEC.md before writing JSON
3. **Author** state files under `src/object-model/` — every custom object with its paired `Name` field
4. **Validate**: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_object_models.py" --workspace .` must exit 0 (a `PostToolUse` hook also lints each Write/Edit as you go)
5. **Review** against `references/review-checklist.md` (semantic checks the validator can't make)
6. **Deploy** explicitly: `/object-models:deploy --alias <alias>`
7. **Verify** in Pulse Web → Settings → Data management

### After deploy — Platform Pages auto-generate

Once a custom object lands in the tenant, Skedulo automatically generates four default Platform
Pages for it (`-create`, `-edit`, `-view`, `-list`), rendered from the state files' display
metadata — no further action needed for a working admin UI. For a customised page, go to
**Pulse Web → Settings → Developer tools → Platform pages** and **duplicate** the
system-generated page rather than editing it directly.
