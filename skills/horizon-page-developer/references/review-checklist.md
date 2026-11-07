# Horizon Page Review Checklist

The single checklist for reviewing page artifacts — used by the build agent's review phase and
`/horizon-page:review`.

## 1. Run the validator

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_horizon_page.py" <workspace-root>
```

Run it; don't re-derive its checks by eye. It settles every mechanically checkable rule and exits
non-zero on any error:

- **HorizonPage** — JSON parses; `metadata.type`; `name`/`templateName`/`slug`/`published`/
  `pageType` present; `published` is boolean; `slug` kebab-case and matching the file stem;
  `pageType` in the eight-value enum; no deprecated `label`/`path`/`componentBundleName`.
- **HorizonTemplate** — JSON parses; `metadata.type`; `name`/`description`/`kind`/`source` present;
  `kind` is `PAGE_LAYOUT` or `PAGE_EXTENDED`; `source` is `"./"` or `"./<template-name>"` with the
  subdirectory actually present; `name` matches both its directory and its filename stem.
- **Cross-artifact** — every `templateName` resolves to a real template; no orphan templates;
  exactly one content file per template; `PAGE_LAYOUT` paired with `content.njk` is an error.
- **content.json** — parses; `id` matches the page slug; `template` is `tabs` or `header-body`;
  `type` is one of the four values; `sections.tabs` present and an array; inline `listConfig` uses
  the map shape, never the `HorizonListConfig` array shape; every level of a nested column path is
  whitelisted in `relationshipResolution.allow`.
- **content.njk** — contains a `<platform-component>` tag with non-empty `package-name` and `name`.

## 2. Check what the validator cannot decide

These need the GraphQL schema, the tenant, or the component bundle — judge them by reading:

- `resourceName` casing matches the object's display name exactly — see the `page-builder` skill's
  **ResourceName Casing** section (the single home for that rule). May be `""` for `type: "custom"`.
- Every field name and relationship path is confirmed against the GraphQL schema. Unverified fields
  render empty with no error, so the validator's silence means nothing here.
- The `<platform-component>` `package-name` and `name` match the bundle's `registerComponent(...)`
  arguments.
- Components use valid `packageName`/`component` pairs — see the `page-builder` skill's component
  library.
- Every completed page in SPEC.md has matching artifacts on disk, and nothing on disk is
  unaccounted for in SPEC.md.
