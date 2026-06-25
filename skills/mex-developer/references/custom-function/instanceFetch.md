# Instance Fetch Handler

Runs when `fetchFunction: true` in `upload_config.json`. Replaces declarative `instanceFetch.json`.

## Data Key Contract

The key in `data: { "MyKey": ... }` **must exactly match** `"pageDataExpression": "formData.MyKey"` in `ui_def.json`. A mismatch silently renders an empty page.

## GraphQL Queries

Write queries in `src/graphql/queries/queries.graphql`, then run `yarn generate`.

**Before running `yarn generate`**, ensure a `.env` file exists in the `custom_functions/` directory:

```text
SKED_BASE_URL=<your-skedulo-base-url>
SKED_API_TOKEN=<your-api-token>
```

Ask the user to create this file if it does not exist. `yarn generate` will fail without these environment variables.

```graphql
query fetchMyObjects($filter: EQLQueryFilterMyObject) {
    page: myObject(filter: $filter) {         # alias must be "page:" for auto-pagination
        edges { node { UID __typename Name } }
        totalCount
    }
}
```

Generated: `<QueryName>Query`, `<QueryName>QueryVariables`, `<QueryName>Document` in `graphql/__graphql/generated.ts`.

**EQL filters:**

| Pattern | Example |
|---|---|
| Equality | `UID == "abc123"` |
| IN list | `JobId IN ["uid1", "uid2"]` |
| IN dynamic | `` `JobId IN ${JSON.stringify(arr)}` `` |
| Null check | `Rating != null` |
| AND | `(ResourceId IN ["${id}"]) AND (JobId IN ["${jobId}"])` |

## `functions/fetcher.ts`

```typescript
import { CustomFetchInput, CustomFetchResult, CustomInput, CustomResult, CustomFunctionStatus }
    from '@skedulo/mex-service-libs/types'
import { MyQueryDocument, MyQueryQuery, MyQueryQueryVariables }
    from '../graphql/__graphql/generated'

export async function fetchMexData(
    input: CustomInput<CustomFetchInput>
): Promise<CustomResult<CustomFetchResult>> {
    const data = await input.services.GraphQLService.executeQueryForDocument<
        MyQueryQuery, MyQueryQueryVariables
    >(MyQueryDocument, { filter: `JobId == "${input.contextObjectId}"` })

    return {
        status: CustomFunctionStatus.SUCCESS,
        data: { "MyKey": data.myObjects?.edges?.[0]?.node ?? null }
        //       ↑ must match pageDataExpression: "formData.MyKey" in ui_def.json
    }
}
```

Rules:
- Always return `CustomFunctionStatus.SUCCESS`; use `data: {}` for missing data, never `CustomFunctionStatus.ERROR`
- Parallel queries: `const [a, b] = await Promise.all([...])`
