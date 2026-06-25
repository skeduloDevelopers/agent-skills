# Static Fetch Handler

Runs when `staticFunction: true` in `upload_config.json`. Replaces declarative `staticFetch.json`.

Returned data is available as `sharedData` in `ui_def.json` — used for vocabulary lists and dynamic UI generation.

## `functions/staticFetcher.ts`

```typescript
import { CustomStaticFetchHandler } from "@skedulo/mex-service-libs/types"
import { CustomFunctionStatus, ObjectDataResult } from "@skedulo/mex-service-libs/types"

export const fetchMexStaticData: CustomStaticFetchHandler = async (input) => {
    return {
        status: CustomFunctionStatus.SUCCESS,
        data: {
            // Vocabulary: consumed as sharedData.__vocabulary.<Key> in ui_def.json
            "StatusOptions": ["Active", "Inactive"],
            // Dynamic UI: triggers engine merge into live form definition
            "__dynamic": buildUIFromSchema(fields) as ObjectDataResult
        }
    }
}
```

## ui_def.json Bindings

**Vocabulary** — bind a select/list widget source:

```text
"sourceExpression": "sharedData.__vocabulary.<Key>"
```

**Dynamic UI** — bind a container to engine-generated UI:

```text
"contentDataExpression": "sharedData.__dynamic.dynamicUIContent"
"localesDataExpression": "sharedData.__dynamic.dynamicLocalization"
```
