# MEX Custom Functions — Implementation Guide

> Use CFs only when declarative `instanceFetch.json`/`staticFetch.json`/`ui_def.json` cannot satisfy the requirement. See [Data Fetching](./data-fetching.md) first.

## 1. Setup

**Scaffold:** `bash scripts/gen-custom-function-boilerplate.sh` — creates all stub files. Fill them in; never create from scratch.

**Enable flags** in `upload_config.json`:

```json
{ "customFunctionFeatures": { "fetchFunction": true, "staticFunction": true, "saveFunction": false } }
```

Only set a flag to `true` after the handler is implemented. `fetchFunction` → runs `instanceFetch.json` when `false`. `staticFunction` → runs `staticFetch.json` when `false`. `saveFunction` → default single-object upsert when `false`.

**Import paths** — always use these exact subpath imports when using `@skedulo/mex-service-libs`:

```typescript
import { CustomFunctionParams, CustomFunctionStatus, CustomInput, CustomRawInput, CustomResult } from "@skedulo/mex-service-libs/types";
import { GraphQLChangeEvent, playbackChangeEvents, defaultGraphQLSave } from "@skedulo/mex-service-libs/utilities";
import { GraphOperationType } from "@skedulo/mex-service-libs/services";
```

**Register handlers** in `params.ts`:

```typescript
import { CustomFunctionParams } from "@skedulo/mex-service-libs/types";
import { fetchMexData } from './functions/fetcher'
import { fetchMexStaticData } from './functions/staticFetcher'
import { saveMexData } from './functions/saver'
import { validateMexData } from './functions/validator'

export const params: CustomFunctionParams = {
    fetch:    { handler: fetchMexData },
    save:     { handler: saveMexData },
    validate: { handler: validateMexData },
    static: { handler: fetchMexStaticData }
}
```

Do not modify `index.backend.ts`, `localDevIndex.ts`, `tracing.ts`, or `graphql/__graphql/generated.ts`.

## 2. Return Shape

All handlers return `CustomResult<T>`:

```typescript
{ status: 'SUCCESS' | 'ERROR', data?: T, message?: string, objectMapping?: Record<string,string> }
```

- `status`: import `CustomFunctionStatus` from `@skedulo/mex-service-libs/types`
- `message`: shown directly to mobile user — keep human-readable
- `objectMapping`: save handler only — maps temp-IDs → real IDs

## 3. Services

```typescript
// GraphQL — use executeQueryForDocument for typed static queries (preferred)
input.services.GraphQLService.executeQueryForDocument<TData, TVars>(document, variables)
// Use executeQuery only for dynamically-built query strings
input.services.GraphQLService.executeQuery<TData, TVars>(queryString, variables)
// For lists where count is unknown — returns flat array of all nodes
input.services.GraphQLService.executeFetchAutoPaginationForDocument<TData, TVars>(doc, vars)

// REST — returns { data: { result: T } }
input.services.BaseAPIService.get<T>(path)
// Paths: /custom/metadata/<ObjectName>  →  fields[] with name/label/type/nillable
//        /custom/fields?schemas=Jobs    →  custom field definitions

// Cache refresh — call after any custom insert
input.services.DataHelperService.refreshEntity(objectName, uid)
// Object names: "Job", "JobTask", "JobAllocation", "JobTag", "Resource"

// Logging — always use instead of console.log
input.logger.info({ key: value }, 'msg' )
input.logger.error({ error: err.message }, 'msg')

// Get resource id
const resourceId = input.userInfo.resourceId

```

## 4. Handler Implementations

| Handler | File | Reference |
|---|---|---|
| Instance fetch | `functions/fetcher.ts` | [instanceFetch.md](./custom-function/instanceFetch.md) |
| Static fetch | `functions/staticFetcher.ts` | [staticFetch.md](./custom-function/staticFetch.md) |
| Single-entity save | `functions/saver.ts` | [single-entity.save.md](./custom-function/single-entity.save.md) |
| Multi-entity save | `functions/saver.ts` | [multi-entity.save.md](./custom-function/multi-entity.save.md) |
| Validate | `functions/validator.ts` | Skip it for now |

### Custom HTTP handler

```typescript
import { CustomFunctionStatus, CustomInput, CustomRawInput, CustomResult } from "@skedulo/mex-service-libs/types";

export async function myHandler(input: CustomInput<CustomRawInput>): Promise<CustomResult<any>> {
    // input.body, input.query, input.headers available
    return { status: CustomFunctionStatus.SUCCESS, data: { result: "..." } }
}
```

Register in `params.ts`: `custom: { handlers: [{ method: 'post', path: '/myHandler', handler: myHandler }] }`

## 5. Error Handling

| Scenario | Return |
|---|---|
| Validation failure | `{ status: ERROR, message: 'human-readable text' }` |
| Missing expected data | `{ status: SUCCESS, data: {} }` |
| Infrastructure failure | `throw Error(...)` — framework catches and returns ERROR |
