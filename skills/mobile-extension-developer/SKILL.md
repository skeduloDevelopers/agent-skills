---
name: mobile-extension-developer
description: Use when building, modifying, or deploying Skedulo Plus mobile extensions — `mex_definition` UI pages, `instanceFetch`/`staticFetch` data, mobile-extension artifact JSON, locale resources.
displayName: Mobile Extensions
status: available
category: Frontend
featured: false
pulseComponents:
  - Skedulo Plus Mobile
sdks: []
filePatterns:
  - "**/*.MobileExtension.json"
  - "**/mex_definition/**"
  - "**/upload_config.json"
---

# Skedulo Mobile Extensions Skill

## Core Principle

**Never construct a mobile extension from memory.** Every schema (artifact JSON, `upload_config`, `metadata`, `ui_def`, fetch payloads) is non-trivial and easy to hallucinate. Always start from a working example.

## When NOT to use

- Web/Horizon extensions — use the relevant Horizon skills.
- Connected functions — use `connected-function-developer`.
- Pure `sked` CLI work with no extension changes — use `skedulo-cli` directly.

## Rules

### Worked examples live in the repo, not this skill

New worked examples → PR against `MobileExtensionExamples`. Examples drift faster than rules; the repo's layout is also what `sked artifacts mobile-extension upsert` consumes.

### Clone the examples repo before any extension work

1. `git clone https://github.com/skeduloDevelopers/MobileExtensionExamples /tmp/MobileExtensionExamples` (or `git pull` if cloned)
2. Read the example closest to your use case (table below)
3. Copy its directory; adapt names/data; preserve structure

| Use case | Start from |
|---|---|
| Bare-minimum / starter | `HelloWorld` |
| View parent record fields | `AccountDetails` |
| View related list (children/grandchildren of context) | `AccountContacts` |
| CRUD on a custom object | `AddProducts` |
| Many-to-many junction (Job ↔ Product) | `JobProducts` |
| Show/hide by data | `ConditionalRendering` |
| Read-only viewer | `ReadOnlyExtension` |
| Junction-record mgmt (attendees) | `JobAttendees` |
| Picklists / lookup data via `staticFetch` | `ConditionalRendering`, `UIComponentsShowcase`, `JobProducts` |
| Component reference | `UIComponentsShowcase` |

### Required directory layout

CLI is strict. Mismatched names fail silently or cryptically.

```text
<repo-root>/
├── <Name>.MobileExtension.json    ← descriptor (deploy target)
└── <Name>/
    ├── upload_config.json         ← name, defId, engineVersion
    └── mex_definition/
        ├── metadata.json          ← summary, displayOrder, contextObject, revisionCount
        ├── ui_def.json            ← pages (keyed object) + firstPage
        ├── instanceFetch.json     ← GraphQL, per-instance
        ├── staticFetch.json       ← GraphQL, cached, shared
        └── static_resources/locales/<lang>.json
```

`defId` MUST match across `<Name>.MobileExtension.json` and `upload_config.json`. `source` in the descriptor is relative to the descriptor file.

### Fetch files are GraphQL, not REST

Both `instanceFetch.json` (per-record, has context UID) and `staticFetch.json` (cached, shared) are GraphQL queries against the Skedulo schema.

### Picklists in `staticFetch.json` — three patterns

Pick one per use case. See examples for full shape:

| Pattern | Use when | Example |
|---|---|---|
| `__vocabulary` | Binding to a real Object picklist field — values stay in sync with schema | `ConditionalRendering` |
| `__predefined` | App-only enums not tied to any schema field | `ConditionalRendering`, `UIComponentsShowcase` |
| `object` GraphQL query | Reference data from a custom object | `JobProducts` |

### Validate schema references against the tenant before deploying

Two distinct concerns:

1. **`mex_definition` file shape** — no offline validator exists. Pre-flight = diff your structure against the closest example. Real shape validation happens on `sked artifacts mobile-extension upsert`.
2. **Object / field names referenced inside fetches and UI** — validate against the live tenant schema via the CLI:
   - `sked artifacts custom-object list --json -a <alias>` — confirm exact object names
   - `sked artifacts custom-field list --objectName <ExactName> --json -a <alias>` — confirm every field your fetch/UI references exists on that object

Doing this **before** deploy catches the most common deploy failures (wrong casing, missing custom field, renamed object). Full rule lives in the `skedulo-cli` skill — read it.

### `sked` CLI rules live in `skedulo-cli`

Read that skill before any `sked` command (alias, `--help`, errors).

## Quick Reference

| Task | Pattern |
|---|---|
| Deploy | `sked artifacts mobile-extension upsert -f <Name>.MobileExtension.json -a <alias>` |
| List | `sked artifacts mobile-extension list --json -a <alias>` |
| Inspect | `sked artifacts mobile-extension get --name <Name> --json -a <alias>` |
| Pull local | `sked artifacts mobile-extension get --name <Name> -o <dir> -a <alias>` |
| Delete (destructive — confirm) | `sked artifacts mobile-extension delete --name <Name> -a <alias>` |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Constructing any JSON file from memory | Clone examples repo. Schemas are non-obvious and vary by component |
| `defId` differs between artifact JSON and `upload_config.json` | They MUST match exactly |
| Hardcoded UI strings | Reference keys in `static_resources/locales/<lang>.json` |
| Designing UI before setting `contextObject` | `metadata.json → contextObject` first; it gates available data |
| Using `instanceFetch` for shared lookup data | Use `staticFetch` — it's cached |
| Treating fetch files as REST | Both are GraphQL |
| `sked` without `-a <alias>` | Always include. See `skedulo-cli` |
| Referencing field names without verifying | Run `custom-field list --objectName <Name>` against tenant first |

## Red Flags — STOP and clone the repo

- About to write `metadata.json` schema from memory
- Confidently authoring `ui_def.json` page structure without a reference open
- Time pressure ("just give me the JSON") with no example file in view
- Producing artifact JSON that doesn't have `metadata.type` or `defId`

All of these mean: pause, `git clone` the examples repo, copy the closest example, then adapt.
