# Multi-Entity Save Handler

Use `playbackChangeEvents` from `@skedulo/mex-service-libs/utilities` when saving multiple related objects in a single operation (e.g. a parent Job with child JobTasks, JobTags, and JobAllocations).

## Key Rules

- `GraphQLChangeEvent` has **no top-level UID** — identity lives in `mutationArg` fields or `mutationAlias`
- Order matters: push parent events before their children
- `mutationAlias` = temp-ID on parent insert; children reference it directly as a FK value (the framework resolves it to the real ID at save time)
- Idempotency: resolve via `input.objectMapping?.[uid] ?? uid`, then skip if not `startsWith('temp-')`
- Result check: `result.contextResults[ownerContextId]`, **not** the entity/schema name
- Always return `objectMapping: result.idMap` even on error (partial saves may have occurred)

## `functions/saver.ts`

```typescript
import { pick } from 'lodash'
import { CustomInput, CustomResult, CustomSaveInput, CustomSaveResult }
    from '@skedulo/mex-service-libs/types'
import { CustomFunctionStatus } from '@skedulo/mex-service-libs/types'
import { GraphQLChangeEvent, playbackChangeEvents } from "@skedulo/mex-service-libs/utilities";
import { GraphOperationType } from "@skedulo/mex-service-libs/services";

export async function saveMexData(
    input: CustomInput<CustomSaveInput>
): Promise<CustomResult<CustomSaveResult>> {
    const changeEvents: GraphQLChangeEvent[] = []

    for (const saveData of input.newInstanceData['MyEntities'] as Record<string, any>[]) {
        // Idempotency: resolve temp-ID → real-ID from a previous save attempt; skip if already real
        const entityUID = input.objectMapping?.[saveData['UID']] ?? saveData['UID']
        if (!entityUID.startsWith('temp-')) continue

        // Parent insert — mutationAlias = temp-ID so children can forward-reference it
        changeEvents.push({
            schema: 'ParentObject',
            ownerContextId: input.contextObjectId,
            mutationType: GraphOperationType.insert,
            mutationArg: pick(saveData, ['Field1', 'Field2']),  // no UID in mutationArg
            mutationAlias: entityUID
        })

        // Child inserts — use the parent's temp-ID as the FK value
        for (const child of saveData['Children'] as Record<string, any>[]) {
            changeEvents.push({
                schema: 'ChildObject',
                ownerContextId: input.contextObjectId,
                mutationType: GraphOperationType.insert,
                mutationArg: { ParentId: entityUID, ...pick(child, ['Field1']) }
                // no mutationAlias needed on children
            })
        }
    }

    const result = await playbackChangeEvents(changeEvents, input.services.GraphQLService)

    // Check success by ownerContextId — not by schema/entity name
    if (result.contextResults[input.contextObjectId].success === false) {
        return {
            status: CustomFunctionStatus.ERROR,
            message: result.contextResults[input.contextObjectId].errors?.join('\n'),
            objectMapping: result.idMap
        }
    }

    // Reference when to use refresh entity below
    // Refresh parent and every newly created entity
   

    return { status: CustomFunctionStatus.SUCCESS, objectMapping: result.idMap }
}
```
## Use case of refreshEntity
### When to use
  - When having exact requirements
### Example 
```typescript
 await Promise.all([
        input.services.DataHelperService.refreshEntity('ParentObject', input.contextObjectId),
        // Refresh child entities with their actual schema only when needed.
        // Example:
        // ...createdChildIds.map((id: string) =>
        //   input.services.DataHelperService.refreshEntity('ChildObject', id)
        // )
    ])
```