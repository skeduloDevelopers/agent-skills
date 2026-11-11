# HorizonListConfig Review Checklist

The single checklist for reviewing list-config artifacts — used by the build agent's review phase
and `/horizon-list-config:review`.

## Schema

- JSON parses; `metadata.type` is `"HorizonListConfig"`
- `objectName`, `name`, `columns`, `ordering`, `displayedActions`, `source` all present
- `columns` entries carry non-empty string `id`, `title`, and `file`, and the `id` values are unique
- `ordering` lists every column `id` exactly once and nothing else — a missing id silently drops
  that column, an unknown one is a typo
- `displayedActions.showActions` is a boolean and `displayedActions.displayedActions` is an array
- `source` is exactly `"./<ObjectName>-DEFAULT_LIST"`
- Each column's `file` matches a real `.njk` file in the source directory (case-sensitive)

## Naming

- Config filename: `<ObjectName>-DEFAULT_LIST.horizon-list-config.json`
- `name` field: `"Default <ObjectName>"`
- Source subdirectory name matches the config filename prefix
- Template files: `<ColumnTitle>-template.njk`

## Templates

- No `extends` — every template is a standalone Nunjucks file
- Status/badge cells use `brz-lozenge`, not raw styled `<span>`
- Navigation links use `_.host.buildPlatformUrl(...)`, not hardcoded platform paths
- Avatars use `brz-avatar` with `label` and `image-src`
- Every field reference (including nested paths like `Account.Name`) was confirmed against the
  GraphQL schema

## Consistency

- Every completed column in SPEC.md has a matching implemented `.njk` file
