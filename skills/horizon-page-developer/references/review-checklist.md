# Horizon Page Review Checklist

The single checklist for reviewing page artifacts — used by the build agent's review phase and
`/horizon-page:review`.

## 1. Run the validator

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate_horizon_page.py" <workspace-root>
```

It finds every `*.horizon-page.json` and `*.horizon-template.json` under the root at any depth, so
`src/horizon-pages/` + `src/horizon-templates/` work as well as `horizon-page/` +
`horizon-template/`. Pass file paths instead of a directory to check only those artifacts.

Run it; don't re-derive its checks by eye. It settles every mechanically checkable rule and exits
non-zero on any error:

- **HorizonPage** — JSON parses; `metadata.type`; `name`/`templateName`/`slug`/`published`/
  `pageType` present; `published` is boolean; `slug` kebab-case and matching the file stem;
  `pageType` in the eight-value enum; no deprecated `label`/`path`/`componentBundleName`.
- **HorizonTemplate** — JSON parses; `metadata.type`; `name`/`description`/`kind`/`source` present;
  `kind` is `PAGE_LAYOUT` or `PAGE_EXTENDED`; `source` is `"./"` or `"./<template-name>"` with the
  subdirectory actually present; `name` matches its filename stem, and its directory too when
  `source` is `"./"`; template names are unique.
- **Cross-artifact** — every `templateName` resolves to a template in the run or elsewhere in the
  page's git repository; no orphan templates when every path is a directory and the run has pages;
  at most one template with `source: "./"` per directory; every content file under a
  `horizon-template(s)/` folder belongs to a template; exactly one content file per template;
  `PAGE_LAYOUT` paired with `content.njk` is an error.
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
- Every `RelatedList` property is in the `page-builder` skill's **RelatedList** property table or
  is a list view property it names. Others, such as `quickFilters`, `queryOverride`,
  `showSavedViews` and `showActionBar`, are ignored silently; `quickFilters` belongs only on
  `Calendar` and `MonthCalendar`. With `lookup` set, `query` and `queryOverrides` do nothing.
- Date/time templates that must show a record's time zone convert first with
  `date("tz", <time zone field>)` and then format; a second argument to a format call, such as
  `date("HH:mm", Timezone)`, is ignored. There is no `dateFormat` filter.
- Every completed page in SPEC.md has matching artifacts on disk, and nothing on disk is
  unaccounted for in SPEC.md.
