# Skedulo Field Types — Quick Reference

> Quick-lookup catalog of the 13 authorable Skedulo Pulse field types, plus 2 read-only-from-platform types (`Geolocation` and `StandardPicklist`) that you may encounter when retrieving a standard-object field. Use this BEFORE writing any custom-field state file — picking the wrong type forces a delete + re-create later (you cannot change `field.type` in-place).
>
> For the full canonical field-type semantics, consult `object-reference/01-object-reference-guide.md` in the `skedulo-platform` skill.

## Table of contents

1. [String — short text](#1-string--short-text)
2. [TextArea — long text](#2-textarea--long-text)
3. [URL](#3-url)
4. [Int — whole number](#4-int--whole-number)
5. [Decimal — fixed-point number](#5-decimal--fixed-point-number)
6. [Boolean — checkbox](#6-boolean--checkbox)
7. [Date — calendar date](#7-date--calendar-date)
8. [Datetime — timestamp](#8-datetime--timestamp)
9. [Time — time-of-day](#9-time--time-of-day)
10. [Picklist (single-select)](#10-picklist-single-select)
11. [Picklist (multi-select)](#11-picklist-multi-select)
12. [Lookup — reference to another object](#12-lookup--reference-to-another-object)
13. [HasMany — reverse collection on the parent](#13-hasmany--reverse-collection-on-the-parent)
14. [Geolocation — standard-only, not custom-authorable](#14-geolocation--standard-only-not-custom-authorable) (special)
15. [StandardPicklist — retrieve-only variant for standard-object picklists](#15-standardpicklist--retrieve-only-variant-for-standard-object-picklists) (special)

## Picking the right type — decision cheat-sheet

| Need | Use |
| --- | --- |
| Short identifier, name, code, URL, anything under ~255 chars | `String` (raise `maxLength` up to ~1000 if needed) |
| Long free-form text, notes, descriptions, multi-line content | `TextArea` (up to 131,072 chars) |
| Whole-number count, quantity, score, priority | `Int` |
| Currency, percentage, weight, decimal measurement | `Decimal` (set `precision` + `scale`) |
| Yes/no, on/off, true/false | `Boolean` |
| Calendar date with no time component (birthday, due-date) | `Date` |
| Timestamp (when something happened) | `Datetime` |
| Time of day with no date (opening hours, shift start) | `Time` |
| Fixed list of options, one selected | `Picklist` (single) |
| Fixed list of options, many selected | `Picklist` (multi) |
| Reference to one other record (parent of this row) | `Lookup` |
| Reverse collection of child rows (children of this row) | `HasMany` |

## Wire-type summary

| Field type | GraphQL wire type | Nullable when not required |
| --- | --- | --- |
| String / TextArea / URL | `String` | yes |
| Int | `Int` | yes |
| Decimal | `BigDecimal` | yes |
| Boolean | `Boolean!` (always present) | no — defaults to `false` or `defaults.defaultValue` |
| Date | `LocalDate` | yes |
| Datetime | `Instant` | yes |
| Time | `LocalTime` | yes |
| Picklist single | `String` | yes |
| Picklist multi | `[String!]` (list) | yes (null = empty list) |
| Lookup | `<TargetObject>` object + `<Name>Id: ID` scalar | yes |
| HasMany | `[<ChildObject>!]!` (non-null list, always present) | n/a — always non-null, empty list when no children |
| Geolocation | `GeoLocation` scalar + `GeoLatitude` / `GeoLongitude` companion fields | yes |

---

## 1. String — short text

**What.** Plain text up to 255 chars by default, raisable. The single most common custom-field type.

**When to use.**

- Short identifiers (`ExternalId`, `BookingReference`, `SKU`).
- Human-readable names, codes, labels.
- Anything under ~500 chars where you don't need multi-line.

**When NOT to use.** Anything over ~500 chars → use `TextArea`. Free-form notes / descriptions → use `TextArea`. URLs → use `URL` (gets format validation for free). Numbers stored as strings → use `Int` or `Decimal` (you lose sorting and range queries).

**Wire type.** `String` (nullable when not required).

**Key constraints.**

- `maxLength` — default 255, raise as needed.
- `unique` — MUST be present as a boolean. Set `false` for a normal String; set `true` to enable GraphQL `upsert` mutations on this field as the external key (common for `ExternalId` and integration keys). Omitting it is rejected by Pulse: `field.constraints.unique must be a boolean value`.
- `defaults.defaultValue` — initial string when row is inserted without a value. **A `required` String MUST set this to a non-empty string** (e.g. `"Untitled"`) — `""` does not satisfy `required` and a required field with no default is rejected at upsert.

**Gotchas.**

- Default `maxLength: 255` is silently truncating-friendly — exceeding it raises an error at write, not a warning. Always set `maxLength` explicitly when you know your data exceeds 255.
- `unique: true` cannot be retrofitted onto a field that already has duplicate values in the tenant. Add it from day one, or clean data first.

---

## 2. TextArea — long text

**What.** Multi-line text up to **131,072 characters**. Allows line breaks (`\n` preserved on the wire).

**When to use.**

- Notes, descriptions, comments, JSON blobs (if you really must), formatted multi-line content.
- Anything over ~500 chars.

**When NOT to use.** Anything you need to sort, range-query, or use in a Lookup → use `String`. Structured data → model it as a child object with proper fields.

**Wire type.** `String` (same as `String` field — the distinction is platform-side: `TextArea` allows the longer cap and the multi-line editor on Platform Pages).

**Key constraints.**

- `maxLength` — default 32,000 per the platform-API default; hard cap is 131,072. Always set explicitly.
- `unique: true` — **rejected by Pulse** on `TextArea`. If you need uniqueness on the text value, use `String` (raise `maxLength` to ~1000 if needed) — uniqueness is supported on `String` but not on `TextArea`.

**Relates to.** Pairs with `String` — the distinction is editor experience (single-line vs textarea) on auto-generated Platform Pages, not the wire shape.

---

## 3. URL

**What.** A `String` field with built-in URL-format validation.

**When to use.** Web links, integration callback URLs, documentation pointers, external system references.

**When NOT to use.** API tokens, internal IDs that happen to look URL-like, free-form text that may or may not be a URL — use `String` to avoid format errors at write time.

**Wire type.** `String` (same as `String` field — validation is platform-side at write time).

**Key constraints.**

- Same as `String`: `maxLength`, `unique`, `defaults`.

**Gotchas.**

- Malformed URLs are rejected at write time, not silently coerced. If you ingest URLs from an upstream system that may produce bad values, use `String` instead and validate downstream.

---

## 4. Int — whole number

**What.** Integer values. No decimal places.

**When to use.**

- Counts, quantities, priorities, sequence numbers.
- Integer IDs from external systems (when not the natural-key `ExternalId` String).
- Scores, ratings (1-5 stars), version numbers.

**When NOT to use.** Currency, percentages, weights, anything with a fractional component → use `Decimal`. Phone numbers, postcodes, SSN-like strings → use `String` (leading zeros matter; range queries don't).

**Wire type.** `Int` (nullable when not required).

**Key constraints.**

- `unique` — MUST be present as a boolean. Set `false` for a normal Int (counts, scores, sequence numbers); set `true` only for a natural-key-style integer field. Omitting it is rejected by Pulse: `field.constraints.unique must be a boolean value`.
- `defaults.defaultValue` — initial integer when row is inserted without a value.

---

## 5. Decimal — fixed-point number

**What.** Fixed-point decimal with configurable `precision` (total digits) and `scale` (digits after the decimal point).

**When to use.**

- Currency (`precision: 18, scale: 2`).
- Percentages (`precision: 5, scale: 2` for 0.00 – 999.99%).
- Weights, measurements, distances.
- Any number that requires non-integer values.

**When NOT to use.** Whole-number counts → use `Int` (cheaper, simpler). Floating-point science data where precision-vs-recall trade-offs matter → out of scope; consider a wire-formatted `String`.

**Wire type.** `BigDecimal` (nullable when not required).

**Key constraints.**

- `precision` — total significant digits, including those after the decimal. Required.
- `scale` — digits after the decimal point. Must be `<= precision`. Required.
- `unique` — MUST be present as a boolean. Set `false` for a normal Decimal; set `true` only for a natural-key-style decimal field (rare). Omitting it is rejected by Pulse: `field.constraints.unique must be a boolean value`.

**Gotchas.**

- `precision >= scale` is enforced by the CLI. `precision: 2, scale: 3` is rejected.
- Set `scale: 0` if you really want integer behaviour — but then prefer `Int`.

---

## 6. Boolean — checkbox

**What.** True/false flag. Always present on the wire — never null.

**When to use.**

- Yes/no flags (`IsActive`, `Cancelled`, `RequiresApproval`).
- Trigger flags for Triggered Actions (e.g. `RequestResumeAll` — admin ticks, Triggered Action fires, CF resets the field to false).

**When NOT to use.** Three-state logic (yes/no/unknown) → use a single-select Picklist with three values. Toggles that need history → consider a separate audit table.

**Wire type.** `Boolean!` (always non-null).

**Key constraints.**

- `required` is moot — Boolean is always present.
- `defaults.defaultValue` — must be `true` or `false`. Defaults to `false` if omitted.

**Gotchas.**

- `null` Boolean is not a thing on Pulse. If you need to model "not yet decided," use a Picklist with an explicit `Pending` value.

---

## 7. Date — calendar date

**What.** A calendar date with no time component. Format `YYYY-MM-DD`.

**When to use.**

- Birthdays, due-dates, certification expiry, contract start/end.
- Anything where the time-of-day doesn't matter.

**When NOT to use.** Timestamps → use `Datetime`. Time-of-day (without a date) → use `Time`.

**Wire type.** `LocalDate` (nullable when not required).

**Key constraints.**

- `defaults.defaultValue` — initial date when row is inserted without a value.

**Gotchas.**

- `Date` has no time-zone. `2026-05-24` is the same calendar date everywhere — useful for things like "expiry day" but a source of bugs if you mix it with `Datetime`.

---

## 8. Datetime — timestamp

**What.** A full timestamp at second precision. Always stored as UTC on the wire (`Instant`).

**When to use.**

- `BookedAt`, `CompletedAt`, `LastSyncedAt`, `RequestedTime`.
- Any "when did this happen" field.

**When NOT to use.** Time-of-day without a date → use `Time`. Calendar dates without a time → use `Date` (storing as `Datetime` at midnight invites time-zone bugs).

**Wire type.** `Instant` (ISO 8601, e.g. `2026-05-24T13:45:00Z`).

**Key constraints.**

- `defaults.defaultValue` — typically omitted; if used, must be ISO-8601.

**Gotchas.**

- Always UTC on the wire. Display-side conversion to the user's time-zone happens in the UI / Platform Page templates.

---

## 9. Time — time-of-day

**What.** A time of day with no date and no time-zone. Format `HH:MM:SS`.

**When to use.**

- Opening hours, shift start/end (when modelled as recurring patterns rather than concrete `Datetime`s).
- Cut-off times ("orders before 16:00 ship same-day").

**When NOT to use.** Concrete timestamps → use `Datetime`. Duration → use `Int` (minutes) or `Decimal` (hours).

**Wire type.** `LocalTime` (nullable when not required).

**Relates to.** Pairs with `Date` when you want to model a recurring schedule (e.g. `OpenDays: [Mon, Tue, Wed]`, `OpenTime: 09:00`, `CloseTime: 17:00`). Skedulo has rich standard objects for shifts and availability — see `references/standard-objects.md` before modelling your own.

---

## 10. Picklist (single-select)

**What.** A fixed list of enumerated string values; one selected at a time.

**When to use.**

- Status fields (`Pending`, `Approved`, `Rejected`).
- Categories (`Type`, `Priority`, `Department`).
- Any field where the set of values is small, finite, and shared across rows.

**When NOT to use.** Free-form text → use `String`. References to other rows → use `Lookup`. Multi-value selection → use multi-select Picklist.

**Wire type.** `String` (nullable when not required). The value sent on the wire is the picklist value's `value` (not the human-friendly `label`).

**Key constraints.**

- `field.allowedValues: [{ value, label, active, default }]` — array of value definitions on the `field` object (not nested under a `picklist` key).
- `field.multipleAllowed: false` — distinguishes single-select from multi-select (must be `false` here; set `true` for entry 11).
- `defaults.defaultValue` — must match one of the `value`s in `allowedValues`. At most one entry should also have `default: true`. **If the field is `required`, you MUST set `defaults.defaultValue`, and it MUST equal the `value` of the entry marked `default: true`** — a required picklist with no default (or whose top-level default disagrees with the `default: true` flag) is rejected at upsert.

**Relates to.** When extending a standard-object picklist (e.g. `Jobs.AbortReason`), use `StandardPicklist` instead — retrieved via `sked artifacts custom-field get --objectName Jobs --name AbortReason`. See entry 15 below.

**Gotchas.**

- **Immutable platform picklists.** Some standard-object picklists (`Jobs.JobStatus`, `Jobs.CustomerConfirmationStatus`, `Resources.Category`, `Activities.Type`, `Availabilities.Status`) are system-managed and CANNOT be modified — not via the CLI, not via the Pulse REST API. Do not shadow them with a custom `Status` field; pick a different name (`ApprovalState`, `WorkflowStage`, etc.).
- Picklist value `value` is the wire identifier — once data is written, renaming a `value` orphans existing rows. Add new values; deactivate old ones (`active: false`); never rename in place.

---

## 11. Picklist (multi-select)

**What.** A fixed list of enumerated string values; zero, one, or many selected.

**When to use.**

- Tags, capabilities, skills, attributes ("supports {English, French, Spanish}").
- Multi-region assignments where Skedulo's standard `*Tags` junction objects don't fit.

**When NOT to use.** Single-value selection → use single-select Picklist. References to rows → use `HasMany` of a join object (or one of Skedulo's standard `*Tags` patterns — check `references/standard-objects.md` first).

**Wire type.** `[String!]` (list of strings; `null` represents an empty selection).

**Key constraints.** Same as single-select Picklist — `field.allowedValues` array; `field.multipleAllowed: true` (the only difference from single-select); `defaults.defaultValue` is an array of `value`s, and multiple `allowedValues` entries may have `default: true`.

**Relates to.** Single-select Picklist. If you find yourself wanting "exactly N selected" semantics, multi-select Picklist isn't the right tool — model it as N separate Lookups or N Boolean flags.

**Gotchas.**

- Same immutability + rename caveats as single-select.
- Multi-select Picklists are harder to query with `WHERE`-style filters in GraphQL than single-select; if filtering on the value is critical, consider single-select + a separate row per value.

---

## 12. Lookup — reference to another object

**What.** A reference from this row to one row on another object (the "parent" / many-to-one direction). Pulse auto-exposes BOTH the lookup object (`Account`) AND the scalar ID (`AccountId`) at the GraphQL layer.

**When to use.**

- "This row belongs to / is owned by / references one of those rows."
- `Job.Account`, `JobAllocation.Resource`, `Note.RelatedAccount`, `CustomChild.Parent`.

**When NOT to use.** Many-to-many → model with a junction object that has two Lookups. The reverse direction (parent → children) → use `HasMany` on the parent (entry 13).

**Wire type.** Two fields at GraphQL: `<LookupName>: <TargetObject>` (the object) AND `<LookupName>Id: ID` (the scalar ID). Both surfaced automatically from a single Lookup state file.

**Key constraints.**

- `relationship.targetObjectName` — the parent object the Lookup points at (e.g. `Accounts`).
- `required` — common; makes the Lookup mandatory at insert.
- `defaults` — typically omitted; setting a default Id is unusual.

**Relates to.**

- **HasMany** on the parent — the reverse direction. A Lookup does NOT automatically create a HasMany on the parent; the parent's HasMany is a separate authorable state file that BINDS to this Lookup via the scalar Id (`<LookupName>Id`).
- The parent object must exist in the tenant before this Lookup can be deployed (deploy order: parent object → this Lookup field → parent's HasMany).

**Gotchas.**

- Cannot Lookup to itself in a circular-required way (chicken-and-egg at insert).

---

## 13. HasMany — reverse collection on the parent

**What.** The reverse-relationship field that exposes the child collection on the parent (e.g. `Account.Notes`, `DemoObject.DemoChildObjects`).

**When to use.**

- When the parent record needs to render or query its children (related-list tab on the parent's Platform Page; child collection in a GraphQL query starting from the parent).
- The forward Lookup on the child already gives you the parent → "I have a child" semantics implicitly; HasMany makes the parent → children traversal explicit and queryable.

**When NOT to use.** When you only ever query starting from the child (you don't need the parent → children traversal). When the relationship is many-to-many — model as a junction object instead. When the relationship is one-to-one (rare) — use a Lookup on the child without a HasMany on the parent.

**Wire type.** `[<ChildObject>!]!` — non-null list, always present, empty list when no children.

**Key constraints.**

- **No `constraints` block.** Unlike all other field types, HasMany has NO `field.constraints` — no `required`, `unique`, `accessMode`. Reverse collections are inherently read-only views of child rows. The CLI rejects HasMany state files that include a `constraints` block.
- `relationship.targetObjectName` — the child object name (the "many" side).
- `relationship.targetObjectIdFieldName` — the **scalar Id** of the Lookup field on the child (`<ChildLookupName>Id`, e.g. `OwnerId` not `Owner`). The `Id` suffix is mandatory.

**Relates to.**

- **Lookup** on the child — the forward direction. Every HasMany binds to exactly one Lookup field on the child via `targetObjectIdFieldName`. A child object with multiple Lookups back to the same parent supports multiple HasManys on the parent — each binding to a different scalar Id.
- **Deploy order matters.** Parent custom-object → child custom-object → child Lookup field → parent HasMany field. Deploying the HasMany before the child Lookup exists raises `DataSchemaRelationshipOverlayNotFound`.

**Gotchas.**

- HasMany does NOT auto-appear when a child has a Lookup. You must explicitly create the HasMany state file on the parent.
- `display.label` is what shows in the related-list UI. Skedulo conventionally uses the singular noun ("Note", "Inspection") because the related-list says "Notes (5)" — doubling the plural is awkward.
- `editableOnMobile` flag exists in the state file (CLI schema requires it) but is a no-op — HasMany is inherently read-only on mobile.

---

## 14. Geolocation — standard-only, not custom-authorable

**What.** A Lat, Long pair stored as `BigDecimal`s. Supports the `GeoLocation` scalar in GraphQL for distance-based filtering and ordering.

**When you'll encounter it.** Only on standard objects that already have it (`Jobs.GeoLocation`, `Resources.GeoLocation`, `Locations.GeoLocation`, etc.). Custom `Geolocation` fields **cannot be created** — only standard ones are supported.

**When NOT to use.** Don't try to add it as a custom field — the CLI will reject the state file. If you need to store coordinates on a custom object, use two `Decimal` fields (`Latitude` + `Longitude`) and do distance math yourself (or pass through Skedulo's geoservices API).

**Wire type.** `GeoLocation` scalar — but cannot be queried directly in GraphQL field selection. Use the auto-generated `GeoLatitude` + `GeoLongitude` companion fields to retrieve the values.

**Relates to.** Pairs with the companion fields `<FieldName>GeoLatitude` and `<FieldName>GeoLongitude` that Pulse auto-generates alongside every standard `Geolocation` field.

**Gotchas.**

- Custom `Geolocation` fields rejected — common surprise. Plan for two `Decimal` fields if you need coordinates on a custom object.
- Cannot select the `Geolocation` field directly in a GraphQL query — must select the companion `GeoLatitude` / `GeoLongitude` fields instead.

---

## 15. StandardPicklist — retrieve-only variant for standard-object picklists

**What.** The type emitted when you retrieve an existing **standard-object picklist** (e.g. `Jobs.AbortReason`) via `sked artifacts custom-field get`. NOT a type you author from scratch — it appears only as the result of round-tripping an existing standard-object picklist.

**When you'll encounter it.** Whenever you modify a standard-object picklist's values via the CLI flow:

```bash
sked artifacts custom-field get --objectName Jobs --name AbortReason -o .
# Edit the returned Jobs-AbortReason.custom-field.json — add / deactivate values
sked artifacts custom-field upsert -f Jobs-AbortReason.custom-field.json
```

The retrieved state file has `field.type: "StandardPicklist"` — NOT `"Picklist"`. Do not change it.

**Wire type.** Same as `Picklist` (single) — `String` on the wire. The `StandardPicklist` type marker tells the platform "this is a modification of an existing standard picklist," not "create a new custom picklist."

**Relates to.**

- **`Picklist` (single)** — same wire shape, different lifecycle. `Picklist` is for fresh custom picklists you create; `StandardPicklist` is the round-trip type for existing standard-object picklists you modify.
- **Pulse `/custom/vocabulary` REST API** — an alternate route for modifying standard-picklist values, with the additional ability to express picklist-value **dependencies** (which the CLI route does not support). Use REST when you need dependent picklists; use CLI for value-only changes.

**Gotchas.**

- **Immutable platform picklists cannot be modified by this flow.** The five system-managed standard-object picklists listed under §10 → Gotchas → "Immutable platform picklists" reject both the CLI flow above AND the `/custom/vocabulary` REST API. The `StandardPicklist` retrieve will succeed, but the matching upsert is rejected.
- Don't try to upsert a `StandardPicklist` state file with `field.type: "Picklist"` — the platform treats those as two different artifact types. Round-trip preserves the type marker; never change it.

---

## How to use this reference

1. **Picking a type for a new custom field.** Start at the "Picking the right type" decision cheat-sheet. Drill into the specific type section if you're unsure about edge cases (max length, precision/scale, defaults).
2. **Reading a retrieved state file.** Match the `field.type` value to the section heading here. `String` / `TextArea` / `URL` / `Int` / `Decimal` / `Boolean` / `Date` / `Datetime` / `Time` / `Picklist` / `Lookup` / `HasMany` / `Geolocation` / `StandardPicklist`.
3. **Modelling a relationship.** Forward direction (this row → one of those) = `Lookup` (entry 12). Reverse direction (this row → many of those) = `HasMany` on the parent (entry 13). Many-to-many = junction object with two Lookups. See `references/standard-objects.md` for the standard-object catalog before inventing a new junction.
4. **Modifying a standard-object picklist.** Retrieve with `sked artifacts custom-field get`, edit the values array, upsert. The `field.type` will be `StandardPicklist` — do not change it. For picklist-value dependencies, use the Pulse REST `/custom/vocabulary` API instead.

For the full state-file shape (every JSON key, every constraint flag), see `SKILL.md` § "The 13 Field Types" — this reference is a quick-pick companion, not a replacement for the full state-file examples.
