# Page Builder

Author the `content.json` (PageConfiguration) that a Skedulo Horizon Page Builder template renders.

## Use this skill when

- Building a list, detail, or create page from Page Builder components
- Adding tabs, headers, field layouts, or related lists to a page
- Configuring an inline `listConfig`: columns, ordering, sorting, `depth`
- Writing Nunjucks column templates or component properties
- Embedding a registered React component via Page Builder JSON

## Key rules

- `id` must match the page's `slug`
- `template` is `tabs` or `header-body`; `type` is `object_record`, `list`, `create`, or `custom`
- Object properties use the schema's exact casing (`JobStatus`, not `Status`) — verify every field
  and relationship path against the GraphQL schema, because unverified fields render empty with no
  error
- Inline `listConfig.columns` is a **map** of id → `{title, template}`, never the
  `HorizonListConfig` artifact's array shape
- `relationshipResolution.allow` must whitelist **every level** of a nested path
  (`JobAllocations`, `JobAllocations.Resource`, `JobAllocations.Resource.Name`) — a missing level
  silently yields empty output, even at higher `depth`
- Use the lowest `depth` that satisfies the columns; default to `1`
- The component is `Container`, not `LayoutContainer`
- For the `HorizonPage` / `HorizonTemplate` artifact schemas, see `horizon-page-developer`
