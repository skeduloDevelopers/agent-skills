# Skedulo Standard Objects — Quick Reference

> Quick-lookup catalog of the 49 Skedulo Pulse standard objects, distilled from the canonical object reference. Use this BEFORE proposing any new custom object — if a standard object already covers the concept, extend it with custom fields rather than inventing a new one.
>
> For full field-level detail (every field, every description, every validation rule), consult the canonical reference: `object-reference/02-standard-objects.md` in the `skedulo-platform` skill.

## Universal system fields

Every standard object has the following read-only system fields, populated automatically by the platform. They are not repeated in each object section below:

- `UID` — primary key (string, the canonical identifier).
- `CreatedDate` / `LastModifiedDate` — timestamps.
- `CreatedBy` / `LastModifiedBy` — lookups to `Users` (with paired `CreatedById` / `LastModifiedById`).

## Table of contents

- [AccountResourceScores](#accountresourcescores)
- [Accounts](#accounts)
- [AccountTags](#accounttags)
- [Activities](#activities)
- [ActivityResources](#activityresources)
- [Attendees](#attendees)
- [Availabilities](#availabilities)
- [AvailabilityPatternResources](#availabilitypatternresources)
- [AvailabilityPatterns](#availabilitypatterns)
- [AvailabilityTemplateEntries](#availabilitytemplateentries)
- [AvailabilityTemplateResources](#availabilitytemplateresources)
- [AvailabilityTemplates](#availabilitytemplates)
- [ClientAvailabilities](#clientavailabilities)
- [Contacts](#contacts)
- [ContactTags](#contacttags)
- [HolidayRegions](#holidayregions)
- [Holidays](#holidays)
- [JobAllocations](#joballocations)
- [JobDependencies](#jobdependencies)
- [JobOffers](#joboffers)
- [JobProducts](#jobproducts)
- [Jobs](#jobs)
- [JobTags](#jobtags)
- [JobTasks](#jobtasks)
- [JobTimeConstraints](#jobtimeconstraints)
- [LocationResourceScores](#locationresourcescores)
- [Locations](#locations)
- [Products](#products)
- [RecordFilters](#recordfilters)
- [RecurringSchedules](#recurringschedules)
- [Regions](#regions)
- [ResourceJobOffers](#resourcejoboffers)
- [ResourceOverrideRegions](#resourceoverrideregions)
- [ResourceOverrides](#resourceoverrides)
- [ResourceRegions](#resourceregions)
- [ResourceRequirements](#resourcerequirements)
- [ResourceRequirementTags](#resourcerequirementtags)
- [Resources](#resources)
- [ResourceShiftBreaks](#resourceshiftbreaks)
- [ResourceShiftOffers](#resourceshiftoffers)
- [ResourceShifts](#resourceshifts)
- [ResourceTags](#resourcetags)
- [ShiftOffers](#shiftoffers)
- [ShiftOfferShifts](#shiftoffershifts)
- [Shifts](#shifts)
- [ShiftTags](#shifttags)
- [Tags](#tags)
- [UserRegions](#userregions)
- [Users](#users)

## Object groupings

- **Job lifecycle.** `Jobs`, `JobAllocations`, `JobTasks`, `JobProducts`, `JobTimeConstraints`, `JobDependencies`, `Attendees`, `RecurringSchedules` — the work item and everything that hangs directly off it.
- **Resource & availability.** `Resources`, `Activities`, `ActivityResources`, `Availabilities`, `AvailabilityPatterns`, `AvailabilityPatternResources`, `AvailabilityTemplates`, `AvailabilityTemplateEntries`, `AvailabilityTemplateResources`, `ResourceOverrides`, `ResourceOverrideRegions`, `Holidays`, `HolidayRegions` — who can work, and when.
- **Offers & dispatch.** `JobOffers`, `ResourceJobOffers`, `ShiftOffers`, `ResourceShiftOffers`, `ShiftOfferShifts` — opportunity-claim workflow.
- **Shifts & roster.** `Shifts`, `ResourceShifts`, `ResourceShiftBreaks`, `ShiftTags` — rostered shift work, distinct from Job-based work.
- **Tagging system.** `Tags`, `JobTags`, `ResourceTags`, `AccountTags`, `ContactTags`, `ShiftTags`, `ResourceRequirementTags`, `ResourceRequirements` — skills, certifications, requirements attached to many entities via junction tables.
- **Regions & access control.** `Regions`, `ResourceRegions`, `UserRegions`, `HolidayRegions`, `ResourceOverrideRegions` — geographic / timezone scoping and per-user access scoping.
- **Account & contact.** `Accounts`, `Contacts`, `ClientAvailabilities`, `Locations`, `LocationResourceScores`, `AccountResourceScores` — customer-side organization and the inclusion / exclusion overrides for resource eligibility.
- **System & meta.** `Users`, `Products`, `RecordFilters` — platform users, catalog items, and saved EQL filters.

## Quick-pick cheat-sheet

- **Need a generic tag / skill / certification system?** Use `Tags` + the `<Entity>Tags` junction (`JobTags`, `ResourceTags`, `AccountTags`, `ContactTags`, `ShiftTags`, `ResourceRequirementTags`). Do not invent a custom tag taxonomy.
- **Need to allowlist / blocklist resources by account or location?** `AccountResourceScores` and `LocationResourceScores` already exist with `Whitelisted` / `Blacklisted` semantics.
- **Need secondary regions for a resource?** Use `ResourceRegions` (junction), not a custom multi-pick or repeating field.
- **Need recurring work / appointments?** `RecurringSchedules` is the canonical pattern definition; link `Jobs` and `ClientAvailabilities` to it.
- **Need to model a one-off resource region change?** `ResourceOverrides` + `ResourceOverrideRegions`, not a custom "temporary region" field on `Resources`.
- **Need crew or multi-resource job?** Increase `Jobs.Quantity` and add multiple `JobAllocations` and/or `ResourceRequirements`. Do not create a custom "crew" object.
- **Need to track customer attendance?** `Attendees` against the `Job`, do not extend `Contacts`.
- **Need scheduled-vs-actual timing?** `Jobs.EstimatedStart` / `EstimatedEnd` / `ActualStart` / `ActualEnd` and the corresponding `JobAllocations.Time*` fields exist. Do not invent custom timestamp fields.
- **Need a saved filter for a page or component?** `RecordFilters` stores reusable EQL expressions per object type.
- **Want to add a Job status?** Modify the `Jobs.JobStatus` picklist values through the Pulse REST `/custom/vocabulary` API — do not add a custom `Status__c` field on `Jobs`.

---

## AccountResourceScores

**Purpose.** The Resources that are either eligible or ineligible to be allocated to work items for a given Account (account-level inclusion / exclusion).

**When to use.** Allow-list or deny-list specific Resources for a given Account's work — e.g. preferred-tech allowlist, do-not-dispatch blocklist for a sensitive customer. Do not invent a custom join object for the same purpose; this junction already encodes both inclusion and exclusion semantics.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Account` | Lookup(Accounts) | Paired with `AccountId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Blacklisted` | Checkbox | Resource cannot be allocated to this Account's work (referred to as "account exclusions"). |
| `Whitelisted` | Checkbox | Resource is cleared for this Account's work (referred to as "account inclusions"). |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction-style allow/deny list keyed by Account + Resource. Use this for any account-scoped resource eligibility rule — do not invent a custom join.

## Accounts

**Purpose.** An organization, company, or individual involved with your organization (for example, a customer).

**When to use.** Model any organization or individual that work is performed for — typically a customer, but also internal departments, sites, or third parties. Pair with `Contacts` for the human points of contact and `Locations` for physical sites. Do not conflate with `Contacts` — `Accounts` is the org/legal entity, `Contacts` are people within it.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Natural key, up to 255 chars. |
| `Phone`, `Fax` | Text | Up to 40 chars. |
| `BillingStreet` / `BillingCity` / `BillingState` / `BillingPostalCode` | Text | Billing address. |
| `ShippingStreet` / `ShippingCity` / `ShippingState` / `ShippingPostalCode` | Text | Shipping address. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `Contacts` via `Account`
- `Jobs` via `Account`
- `Locations` via `Account`
- `ClientAvailabilities` via `Account`
- `AccountResourceScores` via `Account`
- `AccountTags` via `Account`

**Notes / quirks:** Deprecated fields `Rank`, `RequiresWhitelist` — avoid in new implementations. No primary `Region` lookup on Accounts — Region scoping is via the related `Jobs` / `Locations`.

## AccountTags

**Purpose.** Represents Tags associated with an Account (account-level skill / requirement profile).

**When to use.** Attach a skill, certification, or attribute requirement to an Account so it propagates as a soft or hard preference to that account's work. Do not invent a custom multi-picklist field on `Accounts` to model the same idea — use this junction with the shared `Tags` taxonomy.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Account` | Lookup(Accounts) | Paired with `AccountId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `Required` | Checkbox | If true, `Weighting` must be null. |
| `Weighting` | Integer | Required when `Required = false`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern. Required/Weighting are mutually exclusive — see the cross-cutting tag pattern.

## Activities

**Purpose.** Designated periods for a Resource that are distinct from regular work — admin tasks, breaks, meetings, travel.

**When to use.** Block out non-Job time on a Resource's calendar — admin, meetings, training, travel, breaks. If you need to track work performed for a customer, use `Jobs` instead. For recurring availability patterns rather than one-off non-work blocks, use `AvailabilityPatterns`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `ACT-1234`. |
| `Type` | Picklist | Values: `Meal Break`, `Administration`, `Travel`, `Miscellaneous`. Customizable. |
| `Start`, `End` | DateTime | Scheduled period. |
| `Timezone` | Text | |
| `Resource` | Lookup(Resources) | The owner. Paired with `ResourceId`. |
| `Location` | Lookup(Locations) | Paired with `LocationId`. |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] |
| `Quantity` | Integer | Resources required. |
| `CopiedFrom` | Lookup(Activities) | Self-reference for copy/clone provenance. |
| `Notes` | Text | Up to 10,000 chars. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Resource` → `Resources` (the primary owner)
- `Location` → `Locations`
- `CopiedFrom` → `Activities` (self-reference for clone provenance)

**Children** (MANY of these point back at this row — inbound HasManys):

- `ActivityResources` via `Activity` (additional resources beyond the primary owner)

**Notes / quirks:** A single Activity has one primary `Resource`; additional resources participate via the `ActivityResources` junction.

## ActivityResources

**Purpose.** Resources associated with Activities (junction table for multi-resource activities).

**When to use.** Attach additional Resources to an `Activity` beyond its primary `Resource` — e.g. a training session with several attendees, or a group travel block. Do not invent a custom join; this is the canonical many-to-many.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Activity` | Lookup(Activities) | Paired with `ActivityId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Activity` → `Activities`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the Activity ↔ Resources many-to-many relationship. Do not invent a custom join.

## Attendees

**Purpose.** Contacts associated with Jobs, along with information regarding attendance — used for group events.

**When to use.** Track which `Contacts` are expected at — and showed up for — a group `Job` (training, group appointment, multi-attendee event). Toggle `Jobs.IsGroupEvent` and set `MinAttendees`/`MaxAttendees` to model capacity. Do not extend `Contacts` directly with attendance fields — keep attendance state per-Job here.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Contact` | Lookup(Contacts) | Paired with `ContactId`. |
| `Status` | Picklist | Values: `Attended`, `Absent`, `Cancelled`. [immutable picklist — cannot be modified] |
| `CancelReason` | Picklist | Values: `Illness`, `Family`, `Transport`, `Other`. Customizable. |
| `TimeCancelled` | DateTime | Required when `Status = Cancelled`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`
- `Contact` → `Contacts`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Toggle `Jobs.IsGroupEvent` and use `Jobs.MinAttendees` / `MaxAttendees` to model group capacity. Attendees are Contacts, not Resources.

## Availabilities

**Purpose.** Specific periods of time where Resources are either available or unavailable to be allocated to work.

**When to use.** Record one-off, ad-hoc availability changes for a single Resource — sick day, leave window, overtime offer, occupied block. For recurring weekly patterns, use `AvailabilityPatterns` instead. For temporary region changes during the window, use `ResourceOverrides`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Start`, `Finish` | DateTime | Period. |
| `IsAvailable` | Checkbox | True = available, false = unavailable. |
| `Status` | Picklist | Values: `Pending`, `Approved`, `Declined`. [immutable picklist — cannot be modified] |
| `Type` | Picklist | Values: `Sick`, `Leave`, `Occupied`, `Overtime`, `Weekend Shift`. Customizable. |
| `Notes` | Text | Up to 32,768 chars. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Used for one-off availability changes; for recurring patterns use `AvailabilityPatterns`. The `Status` picklist is fixed.

## AvailabilityPatternResources

**Purpose.** Associates Resources with an Availability Pattern over a time window.

**When to use.** Apply a defined `AvailabilityPattern` to a specific Resource for a date range — e.g. "this technician follows the day-shift pattern from Jan to Mar, then switches to night-shift". The same Resource can switch patterns over time by adding successive rows. Do not invent a custom join.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `AvailabilityPattern` | Lookup(AvailabilityPatterns) | Paired with `AvailabilityPatternId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Start`, `End` | DateTime | The window during which the pattern applies to this Resource. |
| `Status` | Picklist | Values: `Pending`, `Approved`, `Declined`. [immutable picklist — cannot be modified] |

**Parents** (this row points to ONE of these — outbound Lookups):

- `AvailabilityPattern` → `AvailabilityPatterns`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table — applies a pattern to a specific Resource for a date range. Same Resource can switch between patterns over time.

## AvailabilityPatterns

**Purpose.** Recurring patterns of availability (canonical replacement for the older `AvailabilityTemplates`).

**When to use.** Define a reusable recurring availability rule — day-shift, night-shift, four-on-four-off, custom roster — then assign it to Resources via `AvailabilityPatternResources`. This is the modern object; do not use `AvailabilityTemplates` for new builds.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Description` | Text | |
| `Pattern` | Text | JSON object [system-managed; not directly settable] — modify only via the Skedulo web app or the `/availability/patterns` API. |
| `Hash` | Text(32) | Opaque hash code; tamper-detection. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `AvailabilityPatternResources` via `AvailabilityPattern`
- `AvailabilityTemplates` via `AvailabilityPattern` (auto-populated on legacy migration)

**Notes / quirks:** Do not edit `Pattern` directly via generic mutation APIs — use the dedicated `/availability/patterns` endpoint. Supersedes `AvailabilityTemplates`.

## AvailabilityTemplateEntries

**Purpose.** Templated availability for a single day within an Availability Template.

**When to use.** Only when maintaining or migrating an existing legacy `AvailabilityTemplates` deployment. For new work, model recurring availability with `AvailabilityPatterns` + `AvailabilityPatternResources` instead — this object is part of the legacy stack.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `AvailabilityTemplate` | Lookup(AvailabilityTemplates) | Paired with `AvailabilityTemplateId`. |
| `Weekday` | Picklist | Values: `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`, `SUN`. [immutable picklist — cannot be modified] |
| `StartTime`, `FinishTime` | Integer | 24-hr `0000`–`2359` representation. |
| `IsAvailable` | Checkbox | |

**Parents** (this row points to ONE of these — outbound Lookups):

- `AvailabilityTemplate` → `AvailabilityTemplates`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Belongs to the legacy `AvailabilityTemplates` workflow; new builds should use `AvailabilityPatterns`.

## AvailabilityTemplateResources

**Purpose.** Associates a Resource with an Availability Template.

**When to use.** Only when maintaining or migrating an existing legacy `AvailabilityTemplates` deployment. For new work, use `AvailabilityPatternResources` instead. The `Migrated` flag indicates whether each row has already been ported to the modern stack.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `AvailabilityTemplate` | Lookup(AvailabilityTemplates) | Paired with `AvailabilityTemplateId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Migrated` | Checkbox | True once migrated to an `AvailabilityPatternResource`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `AvailabilityTemplate` → `AvailabilityTemplates`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Legacy. Junction for the older templates concept; prefer `AvailabilityPatternResources` going forward.

## AvailabilityTemplates

**Purpose.** Templated periods of availability. Note: superseded by `AvailabilityPatterns`.

**When to use.** Only when interacting with already-deployed legacy templates that haven't yet been migrated. For new builds, use `AvailabilityPatterns` — do not extend this object with custom fields.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Start`, `Finish` | Date | Effective window. |
| `Global` | Checkbox | If true, applies to all Resources. |
| `AvailabilityPattern` | Lookup(AvailabilityPatterns) | [system-managed; not directly settable] Auto-populated when this template has been migrated. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `AvailabilityPattern` → `AvailabilityPatterns` (system-set on migration)

**Children** (MANY of these point back at this row — inbound HasManys):

- `AvailabilityTemplateEntries` via `AvailabilityTemplate`
- `AvailabilityTemplateResources` via `AvailabilityTemplate`

**Notes / quirks:** Legacy object. Do not extend with custom fields for new use cases — use `AvailabilityPatterns` instead.

## ClientAvailabilities

**Purpose.** Availability associated with an Account or Contact (customer-side preferences, distinct from Resource availability).

**When to use.** Capture when an Account or Contact is available (or prefers to be scheduled) so the scheduler / optimizer can honor customer-side windows. Either `Account` or `Contact` may be set — or both. Link to a `RecurringSchedule` for repeating preferences. Do not confuse with `Availabilities`, which is the Resource-side equivalent.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Account` | Lookup(Accounts) | Optional. Paired with `AccountId`. |
| `Contact` | Lookup(Contacts) | Optional. Paired with `ContactId`. |
| `Start`, `End` | DateTime | The availability window. |
| `PreferredStart`, `PreferredEnd` | DateTime | Preferred sub-window inside the availability. |
| `IsAvailable` | Checkbox | |
| `RecurringSchedule` | Lookup(RecurringSchedules) | Optional, paired with `RecurringScheduleId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts` (optional)
- `Contact` → `Contacts` (optional)
- `RecurringSchedule` → `RecurringSchedules` (optional, for repeating preferences)

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Either Account OR Contact may be populated (or both). Used by schedulers to honor customer-preferred windows.

## Contacts

**Purpose.** A person associated with an Account.

**When to use.** Model a human point of contact within an `Account` — site contact, decision-maker, attendee. Use `Attendees` (not `Contacts` directly) to model per-Job attendance. Do not conflate with `Users` (login identities) or `Resources` (allocatable workers) — Contacts are customer-side people, not internal staff.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `FirstName`, `LastName` | Text | |
| `FullName` | Text | [system-managed; not directly settable] Read-only, concatenated. |
| `Title` | Text | E.g. Mr/Mrs/Dr. |
| `Email` | Text | |
| `Phone`, `MobilePhone` | Text | |
| `Account` | Lookup(Accounts) | Paired with `AccountId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |
| `Mailing*` (Street/City/State/PostalCode) | Text | Primary address. |
| `Other*` (Street/City/State/PostalCode) | Text | Secondary address. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts`
- `Region` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- `ClientAvailabilities` via `Contact`
- `ContactTags` via `Contact`
- `Attendees` via `Contact`
- `Jobs` via `Contact`

**Notes / quirks:** `FullName` is derived — do not try to write to it. Use `Attendees` (not `Contacts` directly) to model job attendance.

## ContactTags

**Purpose.** Tags associated with Contacts.

**When to use.** Attach a skill, certification, or attribute tag to a Contact — typically a customer-side preference (e.g. "preferred language: Spanish"). Do not invent a custom multi-picklist on `Contacts`; reuse the shared `Tags` taxonomy via this junction.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Contact` | Lookup(Contacts) | Paired with `ContactId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `Required` | Checkbox | If true, `Weighting` must be null. |
| `Weighting` | Integer | Required when `Required = false`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Contact` → `Contacts`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern.

## HolidayRegions

**Purpose.** Regions associated with Holidays.

**When to use.** Scope a `Holiday` to one or more `Regions` so it only applies to Resources in those regions. If the holiday applies to every Resource regardless of region, set `Holidays.Global = true` and skip this junction entirely.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Holiday` | Lookup(Holidays) | Paired with `HolidayId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Holiday` → `Holidays`
- `Region` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for region-scoped holidays. Set `Holidays.Global = true` to skip the junction and apply globally.

## Holidays

**Purpose.** Periods of unavailability for Resources, either globally or within specific Regions (see `HolidayRegions`).

**When to use.** Model statutory or organization-wide unavailability that should block scheduling — public holidays, company shutdowns. Scope to specific regions via `HolidayRegions`, or set `Global = true`. Do not model per-Resource leave here — use `Availabilities` for that.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `StartDate`, `EndDate` | Date | |
| `Global` | Checkbox | If true, applies to all Resources regardless of `HolidayRegions`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `HolidayRegions` via `Holiday`

**Notes / quirks:** Use `Global = true` or attach `HolidayRegions`, not both. No `Resource` lookup — holidays apply by region, not per-resource.

## JobAllocations

**Purpose.** An instance of a Job being allocated to a Resource.

**When to use.** Bind a specific `Resource` to a specific `Job` for the scheduled window, then let the mobile app drive the lifecycle status (`Pending Dispatch` → `Dispatched` → `Confirmed` → `En Route` → `Checked In` → `In Progress` → `Complete`). This is the canonical work-assignment record. Do not add a custom `Status__c` field — extend the `Status` picklist via the REST `/custom/vocabulary` API. Do not write `Time*` / `Geo*` columns directly; the mobile app sets them at status transitions.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `JA-1234`. |
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `ResourceRequirement` | Lookup(ResourceRequirements) | Optional, paired with `ResourceRequirementId`. |
| `Start`, `End`, `Duration` | DateTime / Duration | Scheduled window for this allocation. |
| `Status` | Picklist | Values: `Pending Dispatch`, `Dispatched`, `Confirmed`, `En Route`, `Checked In`, `In Progress`, `Complete`, `Declined`, `Modified`, `Deleted`. [immutable picklist — cannot be modified] |
| `TeamLeader` | Checkbox | |
| `DeclineReason` | Picklist | Values: `Sick`, `OnLeave`, `Conflict`, `Other`. Customizable. |
| `DeclineDescription` | Text | |
| `NotificationType` | Picklist | Values: `push`, `sms`, `other`. Customizable. |
| `PhoneResponse` | Text | Captured when `NotificationType = other`. |
| `TimePublished` / `TimeResponded` / `TimeStartTravel` / `TimeCheckedIn` / `TimeInProgress` / `TimeCompleted` | DateTime | [system-managed; not directly settable] Set automatically as the mobile app advances status. |
| `Geo{StartTravel/CheckedIn/InProgress/Completed}{Latitude/Longitude}` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] [system-managed; not directly settable] Captured at the matching status transition. |
| `EstimatedTravelTime` / `EstimatedTravelDistance` | Duration / Decimal | [system-managed; not directly settable] Calculated from current device location at `En Route`. |
| `TravelTime` / `TravelDistance` | Duration / Decimal | [system-managed; not directly settable] Actual travel between status transitions. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`
- `Resource` → `Resources`
- `ResourceRequirement` → `ResourceRequirements` (optional, when the allocation fulfils a specific requirement)

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** The richest object in the schema — most lifecycle telemetry lives here. Never add a custom `Status` field on `JobAllocations`; extend the `Status` picklist via the REST `/custom/vocabulary` API instead. The `Time*` and `Geo*` columns are set by the mobile app; do not write to them directly.

## JobDependencies

**Purpose.** Relationships between two or more Jobs, where a Job is dependent upon the completion of another Job.

**When to use.** Model "Job B can only start after Job A's start/end, with a min/max offset" — e.g. inspect-after-install, follow-up after initial visit, sequenced steps in a multi-stage delivery. Anchors specify which end (Start or End) of each Job the offset is measured from. Do not invent a custom "Predecessor__c" field on `Jobs`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `FromJob` | Lookup(Jobs) | Paired with `FromJobId`. |
| `ToJob` | Lookup(Jobs) | Paired with `ToJobId`. |
| `FromAnchor` | Picklist | Values: `Start`, `End`. [immutable picklist — cannot be modified] |
| `ToAnchor` | Picklist | Values: `Start`, `End`. [immutable picklist — cannot be modified] |
| `ToAnchorMinOffsetMinutes` | Integer | Can be negative or null; not both offsets can be null. |
| `ToAnchorMaxOffsetMinutes` | Integer | Can be negative or null; not both offsets can be null. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `FromJob` → `Jobs`
- `ToJob` → `Jobs`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Self-junction on `Jobs` (FromJob → ToJob). Anchors specify whether the dependency is start-based or end-based on each side.

## JobOffers

**Purpose.** Offers made to resources, providing them with the opportunity to claim or reject Jobs.

**When to use.** Create an opportunity-claim flow where multiple eligible Resources are notified of a Job and the first to accept wins (or the scheduler curates). Always pair with `ResourceJobOffers` to fan out the offer to each candidate Resource. For shift-based offers, use `ShiftOffers` instead.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `ResourceRequirement` | Lookup(ResourceRequirements) | Optional, paired with `ResourceRequirementId`. |
| `Status` | Picklist | Values: `Pending`, `Filled`, `Cancelled`. [immutable picklist — cannot be modified] |
| `CreatedByResource` | Checkbox | True when the resource self-created the offer. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`
- `ResourceRequirement` → `ResourceRequirements` (optional, when the offer targets a specific requirement)

**Children** (MANY of these point back at this row — inbound HasManys):

- `ResourceJobOffers` via `JobOffer` (the per-Resource fan-out of this offer)

**Notes / quirks:** Pair with `ResourceJobOffers` to fan out the offer to multiple eligible resources.

## JobProducts

**Purpose.** Items required for or consumed when undertaking work.

**When to use.** Record what `Products` (parts, consumables, services) are needed for or consumed on a `Job`, with quantity. Use for parts pick-lists, consumption tracking, and billing line items. Do not invent a custom join between `Jobs` and `Products`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `JP-1234`. |
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Product` | Lookup(Products) | Paired with `ProductId`. |
| `ProductName` | Text | [system-managed; not directly settable] Mirrored from the related `Product.Name`. |
| `Qty` | Decimal(16,2) | |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`
- `Product` → `Products`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the Job ↔ Product many-to-many with a quantity payload.

## Jobs

**Purpose.** A unit of work undertaken by one or more Resources for a customer.

**When to use.** Model any discrete unit of work to be performed for a customer — install, repair, visit, appointment, group event. This is the core work-item entity around which most of the schema revolves. For rostered presence at a location (instead of a discrete work item), use `Shifts`. To add or rename statuses, modify the `JobStatus` picklist via the REST `/custom/vocabulary` API — do not add a custom `Status__c` field.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `JOB-1234`. |
| `Description` | Text | Brief summary, up to 255 chars. |
| `JobStatus` | Picklist | Values: `Queued`, `Pending Allocation`, `Pending Dispatch`, `Dispatched`, `Ready`, `En Route`, `On Site`, `In Progress`, `Complete`, `Cancelled`. [immutable picklist — cannot be modified] |
| `Type` | Picklist | Values: `Installation`, `Upgrade`, `Break Fix`, `Maintenance`. Customizable. |
| `Urgency` | Picklist | Values: `Normal`, `Urgent`, `Critical`. Customizable. |
| `AbortReason` | Picklist | Values: `Customer no show`, `Cancelled by customer`, `Appointment missed`. Customizable. |
| `FollowupReason` | Picklist | Values: `Not Ready`, `Needs more time`. Customizable. |
| `CustomerConfirmationStatus` | Picklist | Values: `Pending`, `Confirmed`, `Declined`, `Error`. [immutable picklist — cannot be modified] [system-managed; not directly settable] — set by the `/sms/confirmation_request` API. |
| `Start`, `End`, `Duration` | DateTime / Duration | Scheduled window. |
| `EstimatedStart`, `EstimatedEnd` | DateTime | |
| `ActualStart`, `ActualEnd` | DateTime | [system-managed; not directly settable] Derived from `JobAllocations` status timestamps. |
| `Address` | Text | |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] |
| `Timezone` | Text | [system-managed; not directly settable] Mirrored from the associated `Region`. |
| `Account` | Lookup(Accounts) | Paired with `AccountId`. |
| `Contact` | Lookup(Contacts) | Paired with `ContactId`. |
| `Location` | Lookup(Locations) | Paired with `LocationId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |
| `RecurringSchedule` | Lookup(RecurringSchedules) | Paired with `RecurringScheduleId`. |
| `Parent` | Lookup(Jobs) | Self-reference for follow-up jobs. Paired with `ParentId`. |
| `CopiedFrom` | Lookup(Jobs) | Self-reference for copy provenance. Paired with `CopiedFromId`. |
| `Quantity` | Integer | Number of resources to allocate. |
| `JobAllocationCount` | Integer | [system-managed; not directly settable] Count of non-`Deleted` allocations. |
| `JobAllocationTimeSource` | Checkbox | If true, allocation times override the Job's `Start`/`End`. |
| `IsGroupEvent` | Checkbox | Toggle on for events with `Attendees`. |
| `MinAttendees`, `MaxAttendees` | Integer | Capacity for group events. |
| `CanBeDeclined` | Checkbox | Whether allocated resources can decline. |
| `Locked` | Checkbox | If true, the record cannot be updated. |
| `CompletionNotes`, `NotesComments` | Text | Up to 32,768 chars each. |
| `VirtualMeetingURL`, `VirtualMeetingId`, `VirtualMeetingInfo` | Text | Virtual / hybrid appointment metadata. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts`
- `Contact` → `Contacts`
- `Location` → `Locations`
- `Region` → `Regions`
- `RecurringSchedule` → `RecurringSchedules`
- `Parent` → `Jobs` (self-reference for follow-up jobs)
- `CopiedFrom` → `Jobs` (self-reference for copy provenance)

**Children** (MANY of these point back at this row — inbound HasManys):

- `JobAllocations` via `Job`
- `JobOffers` via `Job`
- `JobProducts` via `Job`
- `JobTags` via `Job`
- `JobTasks` via `Job`
- `JobTimeConstraints` via `Job`
- `Attendees` via `Job`
- `ResourceRequirements` via `Job`
- `JobDependencies` via `FromJob` and via `ToJob`
- `Jobs` via `Parent` (follow-up jobs)
- `Jobs` via `CopiedFrom` (cloned jobs)

**Notes / quirks:** Deprecated fields `AutoSchedule`, `NotifyBy`, `NotifyPeriod` — avoid in new implementations. To add or rename job statuses, modify the `JobStatus` picklist via the REST `/custom/vocabulary` API; do not add a custom `Status__c` field. `ActualStart` and `ActualEnd` cannot be set directly; they are derived from related allocations.

## JobTags

**Purpose.** An instance of a Tag being associated to a Job.

**When to use.** Declare which skills, certifications, or attributes a Resource must (or preferably should) have to work this `Job`. Use `Required = true` for hard matches and `Weighting` (1=Low, 2=Medium, 3=High) for soft preferences during optimization. Do not invent a custom multi-picklist on `Jobs`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `Required` | Checkbox | If true, `Weighting` must be null. |
| `Weighting` | Integer | Required when `Required = false`. Values: 1 (Low), 2 (Medium), 3 (High). |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern. Required tags must match exactly on the resource; weighted tags act as soft preferences during optimization.

## JobTasks

**Purpose.** Tasks (checklist items) associated with a Job.

**When to use.** Add a lightweight per-Job checklist of named steps that can be ticked off as completed — pre-visit prep, on-site procedure, post-visit close-out. Use `Seq` for explicit ordering. For richer task structures (forms, payloads, conditional logic), prefer the MEX / mobile form layer.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Description` | Text | Up to 32,768 chars. |
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Seq` | Integer | Order among related tasks. |
| `Completed` | Checkbox | |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Lightweight per-job checklist. Use `Seq` for explicit ordering.

## JobTimeConstraints

**Purpose.** A window of time used as a hard or soft constraint when scheduling a Job — for SLAs or timeslot restrictions.

**When to use.** Express SLA deadlines or customer-promised timeslots as `Required` (hard) or non-required (soft) windows the optimizer must respect. Multiple constraints can stack on one Job. Use this in preference to custom "SLA deadline" or "appointment window" fields on `Jobs`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Type` | Picklist | Values: `SLA`, `Timeslot`. [immutable picklist — cannot be modified] |
| `StartAfter`, `StartBefore`, `EndBefore` | DateTime | Boundary timestamps. |
| `Required` | Checkbox | True = hard constraint; false = soft. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Use this in preference to custom "SLA deadline" fields directly on `Jobs`. Multiple constraints can stack on one Job.

## LocationResourceScores

**Purpose.** Used when whitelisting or blacklisting Resources at particular Locations (location-level inclusion / exclusion).

**When to use.** Allow-list or deny-list specific Resources for a given Location — e.g. "only senior techs can work at this hazardous site", "don't dispatch this Resource to this restricted site". Do not invent a custom join object; this junction encodes both inclusion and exclusion semantics.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Location` | Lookup(Locations) | Paired with `LocationId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Blacklisted` | Checkbox | Resource cannot work this Location (referred to as "location exclusions"). |
| `Whitelisted` | Checkbox | Resource is cleared for this Location (referred to as "location inclusions"). |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Location` → `Locations`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction-style allow/deny list keyed by Location + Resource. Use this for any location-scoped resource eligibility rule.

## Locations

**Purpose.** Physical locations where work can be carried out.

**When to use.** Model a reusable physical address where work happens — customer site, depot, warehouse, home. Locations can be account-owned (link to `Accounts`) or standalone. Link `Jobs`, `Activities`, and `Shifts` to a Location rather than copying the address onto each work item.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Address` | Text | |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] |
| `Type` | Picklist | Values: `Home`, `Work`. Customizable. |
| `Account` | Lookup(Accounts) | Optional, paired with `AccountId`. |
| `Region` | Lookup(Regions) | Optional, paired with `RegionId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Account` → `Accounts` (optional)
- `Region` → `Regions` (optional)

**Children** (MANY of these point back at this row — inbound HasManys):

- `Jobs` via `Location`
- `Activities` via `Location`
- `Shifts` via `Location`
- `LocationResourceScores` via `Location`

**Notes / quirks:** Deprecated field `RequiresWhitelist` — avoid in new implementations. Locations can be Account-owned or standalone.

## Products

**Purpose.** Items that represent goods and/or services used, sold, or rendered as part of work performed by your organization.

**When to use.** Maintain a simple catalog of parts, consumables, and services that get attached to Jobs via `JobProducts` with a quantity. For more advanced catalogs (price books, configurations, bundles), defer to the source system (ERP / CPQ) and treat `Products` as a sync target.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `ProductCode` | Text | Unique code. |
| `Description` | Text | Up to 4,000 chars. |
| `Family` | Text | Product family grouping. |
| `IsActive` | Checkbox | |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `JobProducts` via `Product`

**Notes / quirks:** Simple catalog object. Attach to Jobs via `JobProducts` with a `Qty`.

## RecordFilters

**Purpose.** A set of filters that can be applied to a record (saved EQL expressions for reuse in pages or components).

**When to use.** Persist a reusable EQL filter for a given object type so pages and components can reference a single named filter (e.g. "My Open Jobs", "Critical Urgency Jobs This Week"). Do not invent a custom "saved view" object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `RF-001`. |
| `Description` | Text | |
| `ObjectType` | Text | The object the filter targets. |
| `Expression` | Text | EQL expression. Up to 32,768 chars. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — referenced indirectly by EQL clients._

**Notes / quirks:** Use this for any persistable saved-filter need; do not invent a custom "saved view" object.

## RecurringSchedules

**Purpose.** The definition of a series of work items that occur in a repeating pattern.

**When to use.** Define a JSON-encoded recurrence (frequency, start/end, timezone, exclusions) once, then link many `Jobs` or `ClientAvailabilities` to it as the repeating series. Use this for any recurring appointment series — do not duplicate the same `Job` N times manually.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `RS-1234`. |
| `Description` | Text | |
| `Summary` | Text | Long-form description, up to 32,768 chars. |
| `Pattern` | Text | JSON: frequency, start/end, time zone, exclusions. |
| `AckAllJobs` | Checkbox | If true, Resources must acknowledge each generated Job separately. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `Jobs` via `RecurringSchedule`
- `ClientAvailabilities` via `RecurringSchedule`

**Notes / quirks:** The `Pattern` field is JSON — treat it as a sub-document. Use this for recurring `Jobs` or recurring `ClientAvailabilities`.

## Regions

**Purpose.** A geographical area within a single timezone where associated Resources can be allocated work.

**When to use.** Define geographic / timezone scoping for the entire platform — almost every work-related entity (`Jobs`, `Shifts`, `Resources`, `Locations`, `Contacts`, `Users`) ties to a Region for visibility and timezone. Do not invent a custom `Country__c` field on related objects — use the standard `CountryCode` picklist on Regions.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Description` | Text | Up to 100 chars. |
| `Timezone` | Text | IANA identifier, e.g. `America/Los_Angeles`. |
| `CountryCode` | Picklist | ISO 3166-1 alpha-2 (~250 values). [immutable picklist — cannot be modified] |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] Central point. |
| `Radius` | Integer | Meters from center to perimeter. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `Resources` via `PrimaryRegion` (a Resource's primary region)
- `UserRegions` via `Region`
- `ResourceRegions` via `Region` (secondary regions)
- `HolidayRegions` via `Region`
- `ResourceOverrideRegions` via `Region`
- `Jobs` via `Region`
- `Shifts` via `Region`
- `Locations` via `Region`
- `Contacts` via `Region`

**Notes / quirks:** Regions are the platform's primary scoping dimension. Don't add a custom `Country__c` field — use the `CountryCode` picklist.

## ResourceJobOffers

**Purpose.** Job Offers made to Resources, detailing their responses and statuses.

**When to use.** Fan out a single `JobOffer` to each candidate Resource and track per-Resource response (`Accept` / `Decline`) and status. This is the "envelope" between the offer and the individual Resource. Do not invent a custom join.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `JobOffer` | Lookup(JobOffers) | Paired with `JobOfferId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Response` | Picklist | Values: `Accept`, `Decline`. [immutable picklist — cannot be modified] |
| `Status` | Picklist | Values: `Pending`, `Declined`, `OfferFilled`, `OfferCancelled`, `ResourceOfferCancelled`. [immutable picklist — cannot be modified] |
| `TimeNotified`, `TimeResponded` | DateTime | [system-managed; not directly settable] |

**Parents** (this row points to ONE of these — outbound Lookups):

- `JobOffer` → `JobOffers`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction between a `JobOffer` and each candidate `Resource`, with per-resource response tracking.

## ResourceOverrideRegions

**Purpose.** Within a `ResourceOverride`, the alternate Region(s) that apply during the override window.

**When to use.** Attach the alternate Region(s) that should apply to a Resource during a `ResourceOverride` window — e.g. "while travelling, this tech also serves regions X and Y". Multiple override regions per window are supported via this junction.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `ResourceOverride` | Lookup(ResourceOverrides) | Paired with `ResourceOverrideId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `ResourceOverride` → `ResourceOverrides`
- `Region` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table — supports multiple override regions per override window.

## ResourceOverrides

**Purpose.** Defines the time period during which an alternative primary region applies to a Resource.

**When to use.** Model a short-term Resource region change — travel assignment, temporary relocation, secondment — by defining a window plus alternate regions (via `ResourceOverrideRegions`) and an alternate home address. Do not add a custom "temporary region" or "travel address" field on `Resources`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Start`, `End` | DateTime | The override window. |
| `Description` | Text | |
| `HomeAddress` | Text | Alternative home address during the window. |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] Coordinates of the override home. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- `ResourceOverrideRegions` via `ResourceOverride`

**Notes / quirks:** Use this for short-term region changes (e.g. travel assignments). Do not add a custom "temporary region" field on `Resources`.

## ResourceRegions

**Purpose.** Secondary Regions associated with a Resource (in addition to `Resources.PrimaryRegion`).

**When to use.** Add steady-state secondary regions to a Resource on top of its `PrimaryRegion` — e.g. a tech who covers two adjacent regions year-round. For time-bound region changes, use `ResourceOverrides` + `ResourceOverrideRegions` instead. Do not invent a custom multi-region representation on `Resources`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Resource` → `Resources`
- `Region` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Deprecated fields `Start`, `End` — avoid in new implementations (use `ResourceOverrides` for time-bound region changes). Junction table — do not invent a custom multi-region representation.

## ResourceRequirements

**Purpose.** Specifies the combination of the number of Resources that are needed for a Job and the specific Tags required for each Resource.

**When to use.** Define crew compositions and skill mixes for a single `Job` — e.g. "1 lead electrician AND 2 apprentices with safety cert". A Job can have multiple requirements (different skill sets / different sub-windows); each `JobAllocation` can optionally link to the specific requirement it fulfils. Do not create a custom "crew" object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `RR-1234`. |
| `Description` | Text | |
| `Job` | Lookup(Jobs) | Paired with `JobId`. |
| `Quantity` | Integer | Number of required Resources. |
| `Duration` | Duration | Minutes. |
| `ScheduledStart`, `ScheduledEnd` | DateTime | |
| `Status` | Picklist | Values mirror `Jobs.JobStatus`. |
| `JobAllocationCount` | Integer | [system-managed; not directly settable] |
| `JobAllocationTimeSource` | Checkbox | |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Job` → `Jobs`

**Children** (MANY of these point back at this row — inbound HasManys):

- `JobAllocations` via `ResourceRequirement`
- `ResourceRequirementTags` via `ResourceRequirement`
- `JobOffers` via `ResourceRequirement`

**Notes / quirks:** Deprecated field `RelativeStart` — avoid in new implementations. A single Job can have multiple requirements (different skill sets / different sub-time-windows). Use this for crew compositions, not custom "crew" objects.

## ResourceRequirementTags

**Purpose.** Tags associated with Resource Requirements.

**When to use.** Attach required (hard) or preferred (weighted) skills/certs to a specific `ResourceRequirement` rather than the whole Job — useful when a Job has heterogeneous crew slots with different skill needs. Do not invent a custom multi-picklist on `ResourceRequirements`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `ResourceRequirement` | Lookup(ResourceRequirements) | Paired with `ResourceRequirementId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `Required` | Checkbox | If true, `Weighting` must be null. |
| `Weighting` | Integer | Required when `Required = false`. Values: 1 (Low), 2 (Medium), 3 (High). |

**Parents** (this row points to ONE of these — outbound Lookups):

- `ResourceRequirement` → `ResourceRequirements`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern, scoped per requirement instead of per-Job.

## Resources

**Purpose.** Individuals, crews, or assets that can be scheduled to perform work.

**When to use.** Represent any allocatable entity that does work — a person (tech, scheduler, nurse), a crew, or an asset (truck, machine). Link to a `User` when the Resource also logs in. Do not conflate with `Users` (a User is a login identity; a Resource is a work-doing entity) or with `Contacts` (customer-side people). Use `ResourceTags` for skills/certifications and `ResourceRegions` for secondary regions — do not add custom multi-pick fields for either.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `User` | Lookup(Users) | Optional, paired with `UserId`. Links a Resource to a login user. |
| `PrimaryRegion` | Lookup(Regions) | Paired with `PrimaryRegionId`. |
| `Category` | Picklist | Values: `Customer Service`, `Installation Technician`, `Electrician`. Customizable. |
| `ResourceType` | Picklist | Values: `Person`, `Asset`. Customizable via REST API only. |
| `EmploymentType` | Picklist | Values: `Full-time`, `Part-time`, `Casual`, `Agency`. Customizable. |
| `NotificationType` | Picklist | Values: `sms`, `push`. Customizable via REST API only. |
| `CountryCode` | Picklist | ISO 3166-1 alpha-2 for mobile-phone country. [immutable picklist — cannot be modified] |
| `Email`, `MobilePhone`, `PrimaryPhone` | Text | |
| `HomeAddress` | Text | |
| `GeoLatitude`, `GeoLongitude` | Decimal(9,6) | [Geolocation; query via GeoLatitude/GeoLongitude] Geocoded from `HomeAddress`. |
| `IsActive` | Checkbox | |
| `Rating` | Integer | Proficiency ranking. |
| `WeeklyHours` | Decimal(5,2) | Optimization fallback when `WorkingHours*` fields are unset. |
| `WorkingHoursMin`, `WorkingHoursMax` | Decimal(5,2) | |
| `WorkingHoursStart` | Date | |
| `WorkingHoursTimePeriod` | Picklist | Values: `Week`, `TwoWeeks`, `FourWeeks`. [immutable picklist — cannot be modified] |

**Parents** (this row points to ONE of these — outbound Lookups):

- `User` → `Users` (optional, links a Resource to a login identity)
- `PrimaryRegion` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- `Activities` via `Resource` (primary owner)
- `ActivityResources` via `Resource`
- `Availabilities` via `Resource`
- `AvailabilityPatternResources` via `Resource`
- `AvailabilityTemplateResources` via `Resource`
- `JobAllocations` via `Resource`
- `AccountResourceScores` via `Resource`
- `LocationResourceScores` via `Resource`
- `ResourceOverrides` via `Resource`
- `ResourceRegions` via `Resource` (secondary regions)
- `ResourceShifts` via `Resource`
- `ResourceShiftOffers` via `Resource`
- `ResourceJobOffers` via `Resource`
- `ResourceTags` via `Resource`

**Notes / quirks:** Deprecated fields `Alias`, `AutoSchedule`, `Notes`, `WorkingHourType` — avoid in new implementations. Use `ResourceTags` for skills/certifications and `ResourceRegions` (junction) for secondary regions — do not add custom multi-pick fields for either.

## ResourceShiftBreaks

**Purpose.** Breaks taken by a Resource during a Shift.

**When to use.** Record one or more break windows within a `ResourceShift` — meal breaks, rest breaks, statutory breaks. Multiple breaks per shift assignment are supported. Do not invent a separate "Break" custom object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `ResourceShift` | Lookup(ResourceShifts) | Paired with `ResourceShiftId`. |
| `Start`, `End` | DateTime | The break window. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `ResourceShift` → `ResourceShifts`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf object that is not pointed to._

**Notes / quirks:** Multiple breaks per shift assignment are allowed.

## ResourceShiftOffers

**Purpose.** Shift Offers made to Resources, detailing their responses and statuses.

**When to use.** Fan out a single `ShiftOffer` to each candidate Resource and track per-Resource response (`Accept` / `Decline`) and status. This is the Shifts analogue of `ResourceJobOffers`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `ShiftOffer` | Lookup(ShiftOffers) | Paired with `ShiftOfferId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Response` | Picklist | Values: `Accept`, `Decline`. [immutable picklist — cannot be modified] |
| `Status` | Picklist | Values: `Pending`, `Declined`, `OfferFilled`, `OfferCancelled`, `ResourceOfferCancelled`. [immutable picklist — cannot be modified] |
| `TimeNotified`, `TimeResponded` | DateTime | [system-managed; not directly settable] |

**Parents** (this row points to ONE of these — outbound Lookups):

- `ShiftOffer` → `ShiftOffers`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** The Shifts analogue of `ResourceJobOffers`.

## ResourceShifts

**Purpose.** An instance of a Shift being allocated to a Resource.

**When to use.** Bind a specific `Resource` to a specific `Shift` for the rostered window, then record actual start/end as the Resource works it. This is the Shifts analogue of `JobAllocations`. For per-Job work assignments, use `JobAllocations` instead. Add custom timesheet payload via custom fields rather than a new object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Shift` | Lookup(Shifts) | Paired with `ShiftId`. |
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `ActualStart`, `ActualEnd` | DateTime | [system-managed; not directly settable] Recorded when the Resource starts / ends the shift. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Shift` → `Shifts`
- `Resource` → `Resources`

**Children** (MANY of these point back at this row — inbound HasManys):

- `ResourceShiftBreaks` via `ResourceShift`

**Notes / quirks:** The Shifts analogue of `JobAllocations`. Add custom timesheet payload via custom fields rather than a new object.

## ResourceTags

**Purpose.** An instance of a Tag being assigned to a Resource, denoting attributes such as skills, qualifications, or certifications.

**When to use.** Assign a skill, qualification, or certification to a Resource — with optional `ExpiryDate` for credentials that expire (license, certification, training). This is the canonical place for resource credentials; do not invent a separate "ResourceCertification" custom object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Resource` | Lookup(Resources) | Paired with `ResourceId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `ExpiryDate` | DateTime | Optional expiry (e.g. license expiration). |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Resource` → `Resources`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern. Note the explicit `ExpiryDate` — use this for credentials and certifications, do not invent a separate "ResourceCertification" object.

## ShiftOffers

**Purpose.** Offers made to resources, providing them with the opportunity to claim or reject Shifts.

**When to use.** Create an opportunity-claim flow for one or more rostered Shifts — Resources receive the offer (via `ResourceShiftOffers`) and the first to accept wins (or scheduler curates). For per-Job opportunity offers, use `JobOffers` instead.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Status` | Picklist | Values: `Pending`, `Filled`, `Cancelled`. [immutable picklist — cannot be modified] |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `ResourceShiftOffers` via `ShiftOffer` (per-Resource fan-out)
- `ShiftOfferShifts` via `ShiftOffer` (the Shifts bundled into the offer)

**Notes / quirks:** A `ShiftOffer` can include multiple `Shifts` (via `ShiftOfferShifts`) and target multiple `Resources` (via `ResourceShiftOffers`).

## ShiftOfferShifts

**Purpose.** The Shifts contained within a Shift Offer.

**When to use.** Bundle one or more `Shifts` into a single `ShiftOffer` so an accepting Resource picks up the whole package (e.g. a weekend roster offered as one unit). Do not invent a custom join between `ShiftOffers` and `Shifts`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `ShiftOffer` | Lookup(ShiftOffers) | Paired with `ShiftOfferId`. |
| `Shift` | Lookup(Shifts) | Paired with `ShiftId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `ShiftOffer` → `ShiftOffers`
- `Shift` → `Shifts`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table — supports bundling multiple shifts into a single offer.

## Shifts

**Purpose.** A specific period in which Resources are scheduled to carry out work at a single location.

**When to use.** Model rostered presence — a Resource is scheduled at a Location for a known time window without a specific work item attached (warehouse shift, retail floor coverage, on-call period). For discrete work items performed for a customer, use `Jobs` instead. Don't blend the two — choose Shifts OR Jobs based on the customer use case.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | Generated, e.g. `SHFT-1234`. |
| `DisplayName` | Text | Short description. |
| `Start`, `End`, `Duration` | DateTime / Duration | |
| `Location` | Lookup(Locations) | Paired with `LocationId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |
| `CopiedFrom` | Lookup(Shifts) | Self-reference for copy provenance. Paired with `CopiedFromId`. |
| `IsDraft` | Checkbox | |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Location` → `Locations`
- `Region` → `Regions`
- `CopiedFrom` → `Shifts` (self-reference for copy provenance)

**Children** (MANY of these point back at this row — inbound HasManys):

- `ResourceShifts` via `Shift`
- `ShiftOfferShifts` via `Shift`
- `ShiftTags` via `Shift`

**Notes / quirks:** Shifts are roster-based (resource fills a known time window at a place); Jobs are work-item-based. Choose the right pattern for the customer use case rather than mixing them.

## ShiftTags

**Purpose.** Used to specify what tags are required for a particular Shift.

**When to use.** Declare which skills, certifications, or attributes a Resource must (or preferably should) have to be rostered onto this `Shift`. Same Required/Weighting semantics as the other `*Tags` objects. Do not invent a custom multi-picklist on `Shifts`.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Shift` | Lookup(Shifts) | Paired with `ShiftId`. |
| `Tag` | Lookup(Tags) | Paired with `TagId`. |
| `Required` | Checkbox | |
| `Weighting` | Integer | 1-3 if not required; ignored when Required. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `Shift` → `Shifts`
- `Tag` → `Tags`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the `Tags` pattern. Same Required/Weighting semantics as the other `*Tags` objects.

## Tags

**Purpose.** Attributes such as skills, qualifications, or certifications — the canonical reusable trait dictionary.

**When to use.** Define a value in the shared taxonomy of skills, certifications, attributes, or labels. Link tags to entities via the `<Entity>Tags` junction tables (`JobTags`, `ResourceTags`, `AccountTags`, `ContactTags`, `ShiftTags`, `ResourceRequirementTags`) — never by adding a custom multi-picklist. Add a new `Type` category via the REST `/custom/vocabulary` API rather than creating a parallel "Certification" object.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `Name` | Text | |
| `Classification` | Picklist | Values: `Global`, `Human`, `Asset`. [immutable picklist — cannot be modified] Restricts which `ResourceType` the tag applies to. |
| `Type` | Picklist | Values: `Skill`. Customizable — add custom tag categories here. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `JobTags` via `Tag`
- `ResourceTags` via `Tag`
- `AccountTags` via `Tag`
- `ContactTags` via `Tag`
- `ShiftTags` via `Tag`
- `ResourceRequirementTags` via `Tag`

**Notes / quirks:** Central object behind the Tags + `<Entity>Tags` pattern. Add a new `Type` picklist value via the REST `/custom/vocabulary` API rather than creating a parallel "Certification" object.

## UserRegions

**Purpose.** Associates a User with a Region (data-access scoping for non-Resource users such as schedulers).

**When to use.** Scope what regions a non-Resource `User` (typically a scheduler) can see and edit. Add or remove rows to expand/restrict their visibility. For Resource-side region membership, use `Resources.PrimaryRegion` + `ResourceRegions` instead.

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `User` | Lookup(Users) | Paired with `UserId`. |
| `Region` | Lookup(Regions) | Paired with `RegionId`. |

**Parents** (this row points to ONE of these — outbound Lookups):

- `User` → `Users`
- `Region` → `Regions`

**Children** (MANY of these point back at this row — inbound HasManys):

- _None — this is a leaf / junction object that is not pointed to._

**Notes / quirks:** Junction table for the User ↔ Region many-to-many. Used to scope what a scheduler can see/edit.

## Users

**Purpose.** Individuals who have access to Skedulo.

**When to use.** Represent any platform-authenticated identity that creates or modifies records — scheduler, administrator, or a Resource who also logs in. Distinct from `Resources` — a `User` is a login account; a `Resource` is a person allocatable to work. The same human typically has both, linked via `Resources.User`. Do not conflate with `Contacts` (customer-side people, no login).

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `FirstName`, `LastName` | Text | |
| `Name` | Text | [system-managed; not directly settable] Concatenation of `FirstName` and `LastName`. |
| `Email` | Text | |
| `MobilePhone` | Text | |
| `IsActive` | Checkbox | If false, the user cannot log in. |
| `UserTypes` | Picklist | Values: `Scheduler`, `Resource`, `Administrator`. Additional roles via the Skedulo web app. |
| `Street`, `City`, `State`, `PostalCode`, `Country` | Text | Address fields. |

**Parents** (this row points to ONE of these — outbound Lookups):

- _None — this is a top-level / root object._

**Children** (MANY of these point back at this row — inbound HasManys):

- `Resources` via `User`
- `UserRegions` via `User`

**Notes / quirks:** Deprecated fields `FullPhotoUrl`, `SmallPhotoUrl` — avoid in new implementations. `Resources` is the work-doing entity; `Users` is the login identity. A Resource may or may not have a linked User; a scheduler User has no linked Resource.

---

## How to use this reference

1. **Before creating a new custom object**, search this catalog for the closest standard object. If a standard object covers ~80% of the concept, add custom fields to it rather than introducing a new object.
2. **For tag-like / skill-like / certification-like concepts**, use the `Tags` + `<Entity>Tags` pattern (with `ExpiryDate` on `ResourceTags` for credentials). Do not invent a parallel taxonomy.
3. **For status / type picklists already defined on a standard object**, modify the picklist values via the REST `/custom/vocabulary` API. Do not add a custom `Status__c` parallel field.
4. **For relationship-extension needs**, prefer using one of the existing junction tables (`*Tags`, `*Resources`, `ResourceRegions`, `HolidayRegions`, `ShiftOfferShifts`, etc.) before inventing your own.
5. **When you genuinely need a new custom object**, refer to the canonical `object-reference/02-standard-objects.md` for full field details and validation rules, then design your custom object so its relationships compose cleanly with the standard graph (Lookups into `Jobs`, `Resources`, `Accounts`, `Regions`, `Locations`, `Tags` are the most common attachment points).
