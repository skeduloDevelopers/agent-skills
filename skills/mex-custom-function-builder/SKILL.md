---
name: mex-custom-function-builder
description: This skill should be used when the user asks to "add custom functions", "write a fetch handler", "write a save handler", "write a validate handler", "implement a static fetch handler", "add server-side logic to a MEX form", "build a custom HTTP endpoint for MEX", "implement dataObserver handlers", "add TypeScript Lambda handlers", "enable fetchFunction", "enable saveFunction", "enable validateFunction", or "enable staticFunction" in a MEX form. Also triggers when the user needs to save to multiple objects atomically, fetch data across multiple objects in one round-trip, compute server-side aggregates, validate against remote data, or generate dynamic UI from live schema.
---

# MEX Custom Function Builder

## What Custom Functions Are

Custom functions (CFs) are TypeScript Lambda (serverless) handlers that run on the Skedulo backend. They extend MEX forms with server-side logic that the declarative engine (`instanceFetch.json`, `staticFetch.json`, `ui_def.json`) cannot express on its own.

**Use CFs only when required.** The declarative engine handles the vast majority of forms. Add a CF only after confirming it is needed using the decision table below.


## Decision Table — Do You Need a CF?

| Requirement | Handler to use |
|---|---|
| Fetch from multiple objects where step 2 depends on step 1 results | `fetchMexData` |
| Compute aggregates (average, count) server-side | `fetchMexData` |
| Build a GraphQL query dynamically from live schema | `fetchMexData` |
| Call a REST API on form open | `fetchMexData` or `fetchMexStaticData` |
| Save data atomically across multiple objects | `saveMexData` |
| Map temp IDs to real IDs after insert | `saveMexData` |
| Validate user input against remote data before save | `validateMexData` |
| Return a dynamic `ui_def` fragment from live schema | `fetchMexStaticData` with `__dynamic` |
| Custom HTTP endpoint called from a `cf.*` expression | custom handler |
| Reactive computed field (e.g., duration from start/end times) | frontend handler in `index.frontend.ts` |

If none of these apply, keep the form fully declarative — see:
- [`mex-developer` skill](../mex-developer/SKILL.md) for declarative forms
- [`data-fetching.md`](../mex-developer/references/data-fetching.md) for GraphQL queries
- [`expressions-binding.md`](../mex-developer/references/expressions-binding.md) for `formData`/`sharedData`/`pageData`
- [`ui/editor-components.md`](../mex-developer/references/ui/editor-components.md) for editors and [`ui/validation.md`](../mex-developer/references/ui/validation.md) for validators

## Choosing Between Instance Fetch and Static Fetch (if user don't explicitly mention)

Before implementing a backend handler, decide which fetch type fits the use case:

| Criterion | Use `fetchMexData` (instance fetch) | Use `fetchMexStaticData` (static fetch) |
|---|---|---|
| Data relates to the current **Job, Resource, or Shift** | Yes | No |
| Uses `contextObject` / `contextObjectId` | Yes | No |
| Tenant-wide data (lists, counts, aggregates not tied to one record) | No | Yes |
| Examples | Fetching job details, resource schedule, shift assignments | Fetching list of projects, counting records, computing tenant-level aggregates |

**Rule of thumb:** If the query needs to know *which* Job/Resource/Shift the user opened, use instance fetch. If the query would return the same result regardless of which record is open, use static fetch.

## When to Use a Frontend Handler (`index.frontend.js`)

Frontend handlers run on-device (no network). Use them for logic that cannot be expressed in `ui_def.json`:

| Use case | Example                                              |
|---|------------------------------------------------------|
| Complex boolean logic | `A && B \|\| !C`, `if/else if/else`, `switch/case`   |
| String formatting for display | Composing a label from multiple fields               |
| JS array/string methods | `array.includes()`, `array.join()`                   |
| Mutating data via built-in helpers | Calling `ExtHelper` utilities                        |
| Lifecycle events | `onPreDataLoad`, `onPreDataSave`, `onInitializeData` |

## The Five Handler Types

| Handler | Export name | Fires when |
|---|---|---|
| Instance Fetch (offline mode) | `fetchMexData` | Form opens — populates `formData`; context-aware (Job/Resource/Shift) |
| Static Fetch (offline mode) | `fetchMexStaticData` | Form opens — populates `sharedData.__vocabulary.*`; tenant-wide data |
| Save (offline mode) | `saveMexData` | User taps Save |
| Validate | `validateMexData` | Before save |
| Custom HTTP (online mode) | any name | `cf.<name>()` expression in `ui_def.json` |

## Project Structure
You can use the scripts in /scripts/gen-custom-function-boilerplate.sh to spin up the custom function quicker
A form with CFs adds a `custom_functions/` directory:

```text
forms/<form-name>/
├── upload_config.json
├── mex_definition/
│   ├── ui_def.json
│   ├── instanceFetch.json      (unused when fetchFunction: true)
│   ├── staticFetch.json        (unused when staticFunction: true)
│   ├── metadata.json
│   └── static_resources/
│       └── locales/
│           └── en.json
└── custom_functions/
    └── custom-function/
        ├── package.json
        ├── tsconfig.json
        ├── params.ts               (define handler for custom function)
        └── src/
            ├── index.backend.ts    (backend entry point)
            ├── index.frontend.ts   (frontend handler entry point, update this if CF frontend is required)
            └── functions/
                ├── fetcher.ts      (fetchMexData implementation)
                ├── saver.ts        (saveMexData implementation)
                ├── validator.ts    (validateMexData implementation)
                └── staticFetcher.ts (fetchMexStaticData implementation)
```

## Implementation Workflow

### Step 0: Scaffold the custom function template

**Prerequisite:** The `sked` CLI must be installed before running the script. The script uses `sked` to install the `@skedulo/plugin-mex` plugin and sync the custom function template. If `sked` is not installed, ask users refer to the Skedulo developer documentation for installation instructions https://github.com/Skedulo/cli

Verify `sked` is available:

```bash
sked --version
```

then run the boilerplate generator script to create the `custom_functions/` directory structure with all required files pre-configured:

```bash
bash scripts/gen-custom-function-boilerplate.sh
```

This produces the full directory tree described in **Project Structure** above, including `index.backend.ts`, `params.ts`, `package.json`, `tsconfig.json`, and stub handler files. Complete Steps 1–4 inside the generated scaffold.

**Before running `yarn generate`** (used to generate GraphQL types from `.graphql` files), ask the user to create a `.env` file inside `custom_functions/` with these required keys:

```text
SKED_BASE_URL=<your-skedulo-base-url>
SKED_API_TOKEN=<your-api-token>
```

`yarn generate` will fail without these environment variables.

### Step 1: Enable the handler in `upload_config.json`

Set the corresponding feature flag to `true`. Only set a flag to `true` when the handler is implemented

```json
{
  "customFunctionFeatures": {
    "fetchFunction": true,
    "staticFunction": false,
    "saveFunction": false,
    "validateFunction": false
  }
}
```

| Flag | Handler activated | `false` fallback |
|---|---|---|
| `fetchFunction` | `fetchMexData` | Engine runs `instanceFetch.json` declaratively |
| `staticFunction` | `fetchMexStaticData` | Engine runs `staticFetch.json` declaratively |
| `saveFunction` | `saveMexData` | Engine performs default save |
| `validateFunction` | `validateMexData` | No pre-save validation |

### Step 2: Register the handler in `params.ts`

```typescript
import { fetchMexData } from "./functions/fetcher";
import { saveMexData } from "./functions/saver";

export { fetchMexData, saveMexData };
```

### Step 3: Implement the handler

See the **Handler Implementation Guides** section in [`custom-functions.md`](../mex-developer/references/custom-functions.md#9-handler-implementation-guides) for complete, annotated examples for each handler type.

### Step 4: Keep the data key contract in sync

The key returned in `fetchMexData`'s `data` object **must exactly match** the binding used in `ui_def.json`. A mismatch produces no error — the page renders empty silently.

```typescript
// fetcher.ts
return {
  status: "SUCCESS",
  data: { "Review": reviewRecord }   // ← key is "Review"
}
```

```json
// ui_def.json
{ "pageDataExpression": "formData.Review" }  // ← must match exactly
```

## Critical Patterns

### Fetch handler return shape

```typescript
return {
  status: "SUCCESS",
  data: {
    "MyLabel": recordOrArray   // key must match formData.<MyLabel> in ui_def.json
  }
}
```

### Save handler
Use `defaultGraphQLSave` to perform save on single object
Use `playbackChangeEvents` to commit multiple objects in a single transaction. The save handler receives the current `formData` snapshot and returns a list of `GraphQLChangeEvent` objects.

See [`custom-functions.md §9.2`](../mex-developer/references/custom-functions.md#121-Multi-entity) for the full `playbackChangeEvents` pattern and temp-ID remapping.

### Validate handler return shape

```typescript
// Block save
return { status: "ERROR", message: "Localized error key" }

// Allow save
return { status: "SUCCESS" }
```

### Static fetch handler — data return shape

```typescript
return {
  status: "SUCCESS",
  data: {
    "Statuses": statusList     // → sharedData.Statuses
  }
}
```

### Static handler — dynamic UI return

Return `__dynamic` to inject runtime-generated UI into the form:

```typescript
return {
  status: "SUCCESS",
  data: {
    "__dynamic": {
      dynamicUIContent: { firstPage: "...", pages: { ... } },
      dynamicLocalization: { "en": { "Key": "Label" } }
    }
  }
}
```

Consumed in `ui_def.json`:

```json
{
  "contentDataExpression": "sharedData.__dynamic.dynamicUIContent",
  "localesDataExpression": "sharedData.__dynamic.dynamicLocalization"
}
```

### Frontend handler

Frontend handlers run in the mobile JS engine in response to `dataObserver`, `events.onPreDataSave`, or button `behavior.query.function`. They cannot make network calls. 
There are some built in cf frontend, reference (../mex-developer/references/custom-function/cf-frontend-helpers.md). Utilize them if needed

```json
// ui_def.json
{
  "dataObserver": [
    {
      "dataExpression": [
        "pageData.WoundHasBeenCompromisedBy"
      ],
      "request": {
        "type": "local",
        "handler": "cf.computeDuration(pageData)"
      }
    }
  ],
}
```

```typescript
// index.frontend.ts
export const recalculateDuration = (params) => {
  // runs on-device; return value is merged into pageData
  return { duration: computeDuration(params.start, params.end) }
}
```

## Reference

The authoritative technical reference for all handler types, services, GraphQL patterns, and worked examples:

- **[`custom-functions.md`](../mex-developer/references/custom-functions.md)** — Complete reference: handler APIs, `CustomInput<T>` envelope, `GraphQLService`, `BaseAPIService`, `DataHelperService`, `playbackChangeEvents`, testing, build, deployment, and three fully annotated worked examples (`food_review`, `create-follow-up-work`, `showcase_dynamic`)

Cross-references for integrating CF output with the declarative engine:
- **[`expressions-binding.md`](../mex-developer/references/expressions-binding.md)** — `formData`, `sharedData`, `pageData` binding contexts
- **[`ui/page-types.md`](../mex-developer/references/ui/page-types.md)** — `upsert`, page-level config; **[`ui/editor-components.md`](../mex-developer/references/ui/editor-components.md)** — `selectEditor`, `dataObserver`; **[`ui/validation.md`](../mex-developer/references/ui/validation.md)** — `validator`
- **[`data-fetching.md`](../mex-developer/references/data-fetching.md)** — GraphQL patterns for use inside fetch handlers
- **[`metadata-upload.md`](../mex-developer/references/metadata-upload.md)** — `upload_config.json` full schema
