# MEX Custom Function Builder

Add server-side TypeScript Lambda handlers (fetch / save / validate / static) to MEX forms when the declarative engine cannot express the requirement.

## Use this skill when

- Adding a `fetchMexData`, `saveMexData`, `validateMexData`, or `fetchMexStaticData` handler
- Saving atomically across multiple objects, or mapping temp IDs to real IDs after insert
- Fetching across multiple objects in one round-trip, or computing server-side aggregates
- Validating user input against remote data before save
- Returning a dynamic `ui_def` fragment from live schema

## Key rules

- Add a custom function only when the declarative engine cannot do it — check the decision table first
- Use `fetchMexData` for record-context data (`contextObject` / `contextObjectId`); use `fetchMexStaticData` for tenant-wide data
- Reactive computed fields belong in a frontend handler (`index.frontend.ts`), not a custom function
- For declarative forms, use `mex-developer`; for WebView forms, use `mexwex-developer`

## Example

```typescript
// functions/ — instance fetch handler
export const fetchMexData = async (ctx, args) => {
  const jobs = await ctx.graphql.fetch(/* GraphQL for the open Job */)
  return { jobs }
}
```
