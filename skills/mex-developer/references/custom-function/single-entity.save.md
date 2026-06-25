# Single-Entity Save Handler

Runs when `saveFunction: true` in `upload_config.json`. Replaces the default single-object upsert.

## Save Utilities

### `graphQLSaveWithPayloadGenerator`

From `@skedulo/mex-service-libs/utilities`. Use when you need to control insert vs update per object, or whitelist specific fields.

```typescript
const result = await graphQLSaveWithPayloadGenerator(input, 'ObjectLabel', (UID, _old, newData) => ({
    mutationType: UID.startsWith("temp-") ? GraphOperationType.insert : GraphOperationType.update,
    mutationArg: pick(newData, ['UID', 'Field1', 'Field2'])  // always whitelist — never send full object
}))
// result.result.idMap → temp-ID → real-ID map
// result.result.contextResults['ObjectLabel'].success → boolean
```

### `defaultGraphQLSave`

From `@skedulo/mex-service-libs/utilities`. Use for simple upserts of the current context object with no field filtering needed.

```typescript
await defaultGraphQLSave(input, 'CurrentJob')
return {
    status: CustomFunctionStatus.SUCCESS,
    objectMapping: {}
}
```

## `functions/saver.ts`

```typescript
import { pick } from "lodash"
import { CustomInput, CustomResult, CustomSaveInput, CustomSaveResult, CustomFunctionStatus }
    from '@skedulo/mex-service-libs/types'
import { GraphOperationType } from "@skedulo/mex-service-libs/services";
import { graphQLSaveWithPayloadGenerator }
    from "@skedulo/mex-service-libs/utilities"

export async function saveMexData(
    input: CustomInput<CustomSaveInput>
): Promise<CustomResult<CustomSaveResult>> {
    const result = await graphQLSaveWithPayloadGenerator(input, 'Review', (UID, _old, newData) => ({
        mutationType: GraphOperationType.insert,
        mutationArg: pick(newData, ['Rating', 'Comment', 'ResourceId', 'JobId'])
    }))

    if (!result.result.contextResults['Review'].success) throw Error('Failed to save Review')

    await input.services.DataHelperService.refreshEntity("Job", input.contextObjectId)
    return { status: CustomFunctionStatus.SUCCESS, objectMapping: { ...result.result.idMap } }
}
```