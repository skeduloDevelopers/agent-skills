# MEX Review Checklist

Use this checklist to validate a completed MEX form. Go through each section and verify all items.

## 1. Structure & Schema

- [ ] Folder `mex_definition/` exists.
- [ ] Files `upload_config.json` (at root), `mex_definition/ui_def.json`, `mex_definition/instanceFetch.json`, `mex_definition/static_resources/locales/en.json`, `mex_definition/staticFetch.json`, `mex_definition/metadata.json` exist and are valid JSON.
- [ ] `upload_config.json` has `name`, `defId`, and `engineVersion`.
- [ ] `mex_definition/metadata.json` has `summary`, `email`, and `contextObject`.
- [ ] `contextObjectFields` in `metadata.json` is only defined when it has at least one entry.

## 2. Data Fetching

- [ ] `mex_definition/instanceFetch.json` and `mex_definition/staticFetch.json` use `"type": "GraphQl"`.
- [ ] `__vocabulary` in `staticFetch.json` follows the `ObjectName:FieldName` format.
- [ ] GraphQL queries follow the MEX JSON format (siblings as keys, `object`, `fields`, `filter`).
- [ ] **CRITICAL**: Filter expressions use `${varName}` syntax (NOT `{{varName}}`).
- [ ] **CRITICAL**: Variables used in `filter` are ALWAYS defined in the `variables` block (e.g., `{"varName": "$job.UID"}`). Reject any filter with variables but no `variables` block.
- [ ] Queries use `"limit"` (NOT `"take"`) for record limiting.
- [ ] Queries fetching a single record use `"limit": 1` to return an object (not an array).
- [ ] Dot notation is used correctly for relationship fields.

## 3. UI Definition

- [ ] `mex_definition/ui_def.json` has `firstPage` and `pages` map at the root.
- [ ] Each page in the `pages` map has exactly ONE Page Type (e.g., `flat`, `list`).
- [ ] If a `flat` page uses `mode: "steps"`, it must have a valid `stepDef` and NO `children`.
- [ ] `stepDef` must contain `stepValue` and a `steps` array with at least one step.
- [ ] Each step in `stepDef.steps` must have a `key` and a `ui.items` array.
- [ ] View Components are correctly nested.
- [ ] Required properties for components (e.g., `type`, `title`, `valueExpression`) are present.
- [ ] Navigation properties (e.g., `itemClickDestination`) use valid page names from the `pages` map.

## 4. Data Binding & Expressions

- [ ] `valueExpression` and `sourceExpression` use correct syntax (e.g., `formData.xxx` or `sharedData.xxx`).
- [ ] `selectEditor` using Picklists (`sharedData.__vocabulary.xxx`) does NOT use `structureExpression`.
- [ ] `selectEditor` using Picklists has `displayExpression` set to `converters.ui.translatePicklist(valueExpression, sourceExpression)` — NOT raw `pageData.FieldName`. This ensures the displayed label matches the vocabulary label rather than the raw stored value.
- [ ] Pages navigated to from a `list` (via `itemClickDestination`) use `pageData.FieldName` for editing, NOT `formData.Array[index]`.
- [ ] Flat pages using `pageDataExpression` bind their editors to `pageData.FieldName`.
- [ ] Localized keys (e.g., in `title`, `text`, `caption`, `placeholder`, `summary`) are PURE STRINGS (e.g., `"MyLabel"`) and NOT wrapped in `${...}` in `ui_def.json` and `metadata.json`.
- [ ] Localized keys correspond to entries in `mex_definition/static_resources/locales/en.json`.
- [ ] Expressions in `showIf` and `mandatoryIf` use supported operators and follow nesting rules.

## 5. Consistency

- [ ] `defId` in `upload_config.json` uses snake_case (underscores) and contains NO hyphens (`-`).
- [ ] `defId` in `upload_config.json` matches the project identifier.
- [ ] `contextObject` in `metadata.json` matches the intended target object.

## 6. Custom Functions (only if the form uses them)

Skip this section if the form has no `custom_functions/` directory and all flags in `upload_config.json` (`fetchFunction`, `staticFunction`, `saveFunction`) are `false`.

- [ ] **Flags match handlers**: Each `true` flag in `upload_config.json` (`fetchFunction`, `staticFunction`, `saveFunction`) has a corresponding registered handler in `params.ts`. No flag is `true` without an implementation.
- [ ] **Data key contract**: The key returned in `fetcher.ts` `data: { "MyKey": ... }` exactly matches `"pageDataExpression": "formData.MyKey"` in `ui_def.json`. Mismatches silently render empty pages.
- [ ] **Handler return shape**: All handlers return `{ status, data?, message?, objectMapping? }`. Fetch handlers use `Status.SUCCESS` for missing data (never `ERROR`). Save handlers include `objectMapping`.
- [ ] **`params.ts` registrations**: All implemented handlers are imported and registered. No handler file exists that is not registered.
- [ ] **GraphQL generated types**: Queries reference types from `graphql/__graphql/generated.ts` (not hand-written). `yarn generate` has been run after any `.graphql` file changes.
- [ ] **Save whitelist**: `graphQLSaveWithPayloadGenerator` uses `pick()` to whitelist fields — never sends full objects.
- [ ] **Cache refresh**: Save handlers call `refreshEntity` after custom inserts.
- [ ] **Untouched scaffold files**: `index.backend.ts`, `localDevIndex.ts`, `tracing.ts`, and `graphql/__graphql/generated.ts` are not modified.
- [ ] **Vocabulary bindings**: If `staticFetcher.ts` returns vocabulary keys, `ui_def.json` select fields reference them as `sharedData.__vocabulary.<Key>`.
