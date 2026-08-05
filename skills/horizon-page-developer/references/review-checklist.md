# Horizon Page Review Checklist

The single checklist for reviewing page artifacts — used by the build agent's review phase and
`/horizon-page:review`.

## HorizonPage schema

- JSON parses; `metadata.type` is `"HorizonPage"`
- `name`, `templateName`, `slug`, `published`, `pageType` all present; `published` is a boolean
- `slug` is kebab-case and matches the file stem
- `pageType` is one of: `PAGE_BUILDER`, `LIST`, `VIEW`, `EDIT`, `CREATE`, `RELATED_LIST`,
  `COLUMN_EDITOR`, `CUSTOM`
- No deprecated fields: `label`, `path`, `componentBundleName` must NOT be present

## HorizonTemplate schema

- JSON parses; `metadata.type` is `"HorizonTemplate"`
- `name`, `description`, `kind`, `source` all present
- `kind` is `"PAGE_LAYOUT"` or `"PAGE_EXTENDED"`
- `source` is `"./"` (flat, default) or `"./<template-name>"` with a matching subdirectory
- Template `name` matches its directory name and the `.horizon-template.json` filename stem

## Cross-references

- Every page's `templateName` exactly matches a template's `name`, and that template directory
  exists
- Content file matches the flavor: `content.json` for `PAGE_LAYOUT` (Page Builder) and
  `PAGE_EXTENDED` Custom Page Builder; `content.njk` for `PAGE_EXTENDED` Direct Nunjucks —
  `PAGE_LAYOUT` paired with `content.njk` is a critical error

## content.json (Page Builder / Custom Page Builder)

- JSON parses; `id` matches the page slug; `template` is `"tabs"` or `"header-body"`; `type` is
  `"object_record"`, `"list"`, `"create"`, or `"custom"`
- `resourceName` casing follows the `page-builder` skill's **ResourceName Casing** section (may be
  `""` for `type: "custom"`)
- `sections.tabs` is present (array); components use valid `packageName`/`component` pairs
- Inline `listConfig` uses the **map** shape (`columns: { id → {title, template} }`) — never the
  `HorizonListConfig` artifact's array shape (see the `page-builder` skill's ListView section)
- Every nested field referenced in a column template has its **full** `relationshipResolution.allow`
  path whitelisted at every level
- Every field name and relationship path was confirmed against the GraphQL schema

## content.njk (Direct Nunjucks)

- Contains a `<platform-component>` tag with non-empty `package-name` and `name` attributes
  matching the bundle's `registerComponent(...)` arguments

## Consistency

- Every completed page in SPEC.md has matching artifacts on disk; no orphan files
