# MEX Data Fetching Reference

MEX supports two fetch strategies, selected via the `type` field in `instanceFetch.json` and `staticFetch.json`:

| Type | Value | When to use |
|---|---|---|
| Declarative GraphQL | `"GraphQl"` | Standard single- or multi-object queries; no server-side logic needed |
| Custom Function | `"CUSTOM"` | Server-side logic required — multi-step queries, aggregates, REST calls, or data from objects the declarative engine cannot reach in one pass |

> **If your form runs in Online Only Mode (`settings.fullOnlineMode: true`), do NOT put CRUD-relevant data in `instanceFetch.json`.** Online mode replaces the offline pre-load with live queries declared inside `ui_def.json`. Mixing the two pipelines causes stale data and unexpected behaviour. See [Online Mode](./online-mode.md), [Online Mode — Queries](./online-mode-queries.md), and [Online Mode — List Page](./online-mode-list-page.md). For online forms, an empty `instanceFetch.json` (`{}`) is the right shape.

## Overview

- **`instanceFetch.json`**: Fetches data specific to the form instance (e.g., details of the current Job). This data is stored in the `formData` context.
- **`staticFetch.json`**: Fetches data that is shared across forms of the same type (e.g., a list of all Products). This data is stored in the **`sharedData`** context.

## JSON GraphQL Format

MEX does not use standard GraphQL strings but a JSON-based representation.

```json
{
  "type": "GraphQl",
  "QueryResultKey": {
    "object": "ObjectName",
    "fields": [
      "Field1",
      "Field2",
      "Relationship.Field3"
    ],
    "filter": "Field1 == '${varName}'",
    "variables": {
      "varName": "$job.UID"
    },
    "orderBy": "Field1 ASC",
    "limit": 10
  }
}
```

### Root Properties
- **`type`**: Either `"GraphQl"` (declarative) or `"CUSTOM"` (custom function). See [Custom Function Fetch](#fetch-type-custom) below.
- **Siblings**: Each top-level key (except `type`) represents a separate query and will be a key in the resulting data context (`formData` or `sharedData`).

### Query Properties
- **`object`**: (Required) The name of the Skedulo object (e.g., `Jobs`, `Resources`, `JobProducts`).
- **`fields`**: (Required) An array of field names. Supports dot notation for child objects (e.g., `Product.Name`).
- **`filter`**: (Optional) A string representing the query filter. **CRITICAL**: Use `${varName}` syntax (NOT `{{varName}}`).
- **`variables`**: (Required if filter uses variables) A map of variable names used in the filter to their source values. **NEVER omit this block if your filter references variables.**
- **`orderBy`**: (Optional) Sort order (e.g., `Name ASC`, `CreatedDate DESC`).
- **`limit`**: (Optional) Maximum number of records to return. **Special behavior**: `"limit": 1` returns a single object (not an array), allowing direct field access like `formData.QueryKey.FieldName` instead of `formData.QueryKey[0].FieldName`.

## Special Variables

MEX provides several built-in variables that can be used in the `variables` block:

- **`$job.UID`**: The UID of the current Job (if the form is Job-contextual).
- **`$resource.UID`**: The UID of the current Resource (if the form is Resource-contextual).
- **`$user.UID`**: The UID of the logged-in user.

## Example: instanceFetch.json

Fetching job details and assigned products:

```json
{
  "type": "GraphQl",
  "JobDetails": {
    "object": "Jobs",
    "fields": ["UID", "Name", "Description", "Status"],
    "filter": "UID == '${jobId}'",
    "variables": {
      "jobId": "$job.UID"
    },
    "limit": 1
  },
  "AssignedProducts": {
    "object": "JobProducts",
    "fields": ["UID", "Qty", "Product.Name", "Product.UID"],
    "filter": "JobId == '${jobId}'",
    "variables": {
      "jobId": "$job.UID"
    }
  }
}
```

**Note**: `JobDetails` uses `"limit": 1` to return a single object. This allows direct access like `formData.JobDetails.Name` (not `formData.JobDetails[0].Name`). `AssignedProducts` returns an array for use with list pages.

## Example: staticFetch.json

Fetching a global list of available products:

```json
{
  "type": "GraphQl",
  "AllProducts": {
    "object": "Products",
    "fields": ["UID", "Name", "Description"],
    "orderBy": "Name ASC"
  }
}
```

## Picklist / Vocabulary Data

Skedulo (especially on Salesforce tenants) uses Picklists for fields with a fixed set of options. MEX can fetch these using the `__vocabulary` key in `staticFetch.json`.

### `staticFetch.json` with Vocabulary
```json
{
  "type": "GraphQl",
  "__vocabulary": {
    "StatusVocab": "Jobs:Status",
    "PriorityVocab": "Jobs:Priority"
  }
}
```
- **Key**: A custom name for the vocabulary (e.g., `StatusVocab`).
- **Value**: `ObjectName:FieldName` of the picklist field.

The results are available in the **`sharedData.__vocabulary`** context and are typically used as the `sourceExpression` for a `selectEditor`.

---

## Fetch Type: CUSTOM

When a form uses a custom function for fetching, set `"type": "CUSTOM"` in `instanceFetch.json` (for `fetchMexData`) or `staticFetch.json` (for `fetchMexStaticData`). No other keys are needed — the engine delegates all data fetching to the Lambda handler.

```json
{
  "type": "CUSTOM"
}
```

This requires the corresponding flag to be enabled in `upload_config.json`:

| File | Flag | Handler |
|---|---|---|
| `instanceFetch.json` | `fetchFunction: true` | `fetchMexData` — populates `formData` |
| `staticFetch.json` | `staticFunction: true` | `fetchMexStaticData` — populates `sharedData` |

The data keys returned by the handler must exactly match the `formData.<key>` or `sharedData.<key>` bindings used in `ui_def.json`. A mismatch produces no error — the page renders silently empty.

For handler implementation details see [`custom-functions.md`](./custom-functions.md).

### Decision Flowchart

```text
Does the user need data from multiple unrelated objects in one load?
  YES → use fetchMexData handler (fetch CF)
  NO ↓
Does the form save to more than one object type?
  YES → use saveMexData handler (save CF)
  NO ↓
Does the form need to validate input against remote data before saving?
  YES → use validateMexData handler (validate CF)
  NO ↓
Does the form need dynamic UI generated from live schema or REST API?
  YES → use fetchMexStaticData handler (static CF)
  NO ↓
Does the form need an on-demand server action from a button press?
  YES → use custom HTTP handler + frontend cf.* expression
  NO → build form declaratively (no CFs needed)
```
