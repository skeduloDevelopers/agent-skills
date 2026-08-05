---
name: horizon-page-developer
description: Core skill for authoring and deploying Skedulo Horizon platform pages. Covers HorizonPage and HorizonTemplate artifact schemas, the three page authoring flavors (Page Builder, Custom Page Builder, and Direct Nunjucks), file structure conventions, and deploy commands.
---

# Horizon Page Developer

A **Horizon page** is a deployable artifact on the Skedulo Pulse Platform that maps a URL slug to a
rendered template. Every page consists of two artifacts:

1. **`HorizonPage`** — metadata file: links a slug + display name to a `HorizonTemplate` by name.
2. **`HorizonTemplate`** — template directory: defines what the page renders.

## Goal

Produce deploy-ready page artifacts: a valid `HorizonPage` JSON plus a matching `HorizonTemplate`
(metadata + `content.json` or `content.njk`) per page, tracked in SPEC.md, reviewed against
`references/review-checklist.md`.

## Guardrails

Platform rules you can't discover by reading the workspace — violations fail silently or at deploy:

- `HorizonPage.templateName` must **exactly** match the `name` field of the `HorizonTemplate` it
  references — a mismatch deploys but the page fails to render at runtime.
- `pageType` must be one of the valid enum values (table below) — anything else is rejected.
- Never generate the deprecated `{name, label, path, componentBundleName}` page shape — it will
  not deploy. Field mapping: `label → name`, `path → slug`, `componentBundleName → templateName`
  (plus add `published` and `pageType`).
- `resourceName` in `content.json` must match the object's display name exactly — see the
  `page-builder` skill's **ResourceName Casing** section (the single home for that rule).
- Verify every field name and relationship path against the GraphQL Schema MCP before referencing
  it — unverified fields render empty with no error.

---

## Three Page Authoring Flavors

| Flavor | Template `kind` | Content file | Use for |
|---|---|---|---|
| **Page Builder** | `PAGE_LAYOUT` | `content.json` (PageConfiguration) | Typed list/detail/create pages composed from Page Builder components; no React. Admin-configurable after deploy. |
| **Custom Page Builder** | `PAGE_EXTENDED` | `content.json` (`type: "custom"`) | Custom-layout page embedding a registered React component via Page Builder JSON. |
| **Direct Nunjucks** | `PAGE_EXTENDED` | `content.njk` | Render a component directly via Nunjucks, bypassing Page Builder entirely. No admin UI. |

**Prefer Page Builder (`content.json`) unless you have a specific reason not to.** Page Builder can
embed both standard platform components and custom registered React components (from any bundle
deployed to the tenant and registered via `registerComponent(...)`), and keeps the page
admin-configurable.

Use **Direct Nunjucks (`content.njk`)** only when the ticket/requirements explicitly request it, OR
when one of these technical conditions applies:

- The component is not registered with Page Builder (no `registerComponent(...)` call), OR
- You need Nunjucks base-template inheritance (`{% extends "base-listview" %}` etc.)

### Which `kind` to use

| `kind` | Use for |
|---|---|
| `PAGE_LAYOUT` | Standard typed pages: `type: "object_record"`, `"list"`, or `"create"` |
| `PAGE_EXTENDED` | Non-standard pages: `type: "custom"` or any Direct Nunjucks (`content.njk`) page |

> Both kinds with `content.json` support custom registered components — the difference is the page
> type, not the component type. For all `content.json` implementation (schema, component library,
> patterns), use the `page-builder` skill.

---

## Embedding an Existing horizon-component Bundle

When a component bundle has already been built (via the `horizon-component` plugin):

1. **Find the registration** — in the bundle's `src/index.ts`:

   ```typescript
   registerComponent('booking-grid', 'BookingGrid', BookingGridComponent, { ... })
   //                 ^^^^^^^^^^^^   ^^^^^^^^^^^
   //                 packageName    component name
   ```

2. **Cross-check** the first argument against the bundle's `package.json` `"name"`.
3. **Choose the flavor**: registration exists → Custom Page Builder
   (`{ "packageName": "booking-grid", "component": "BookingGrid" }` in `content.json`); no
   registration → Direct Nunjucks
   (`<platform-component package-name="booking-grid" name="BookingGrid">`).
4. If no co-located `horizon-component` project exists, ask the user for these values — never
   guess them.

---

## HorizonPage Artifact

**File**: `horizon-page/<slug>.horizon-page.json`

```json
{
  "metadata": { "type": "HorizonPage" },
  "name": "Schedule Plans",
  "templateName": "schedule-plan-list-template",
  "slug": "schedule-plan-list",
  "published": true,
  "pageType": "PAGE_BUILDER"
}
```

| Property | Type | Required | Notes |
|---|---|---|---|
| `metadata.type` | string | Yes | Always `"HorizonPage"` |
| `name` | string | Yes | Display name shown in the admin UI |
| `templateName` | string | Yes | Must match a `HorizonTemplate`'s `name` field exactly |
| `slug` | string | Yes | Unique kebab-case URL identifier — page lives at `/platform/page/<slug>` |
| `published` | boolean | Yes | `true` makes the page live immediately after deploy |
| `pageType` | string | Yes | One of the values below |
| `description` | string | No | Optional display description |

### Valid `pageType` values

| Value | Use for |
|---|---|
| `PAGE_BUILDER` | A declarative Page Builder page (the common case — see the `page-builder` skill) |
| `LIST` | A bare platform list that renders the object's default `HorizonListConfig` unchanged — before choosing this, see the `page-builder` skill's **ListView Component** section |
| `VIEW` | A read-only record view page |
| `EDIT` | A record edit page |
| `CREATE` | A record create page |
| `RELATED_LIST` | A related-list embedded under a record |
| `COLUMN_EDITOR` | A list column-configuration page |
| `CUSTOM` | A fully custom page when no standard type fits — carries no implicit layout or context injection |

---

## HorizonTemplate Artifact

A template is a directory containing a metadata JSON file plus a content file. The `source` field
controls where the content file lives relative to the `.horizon-template.json`.

### `source` field — flat is the default

**Pattern A — content at the directory root (`source: "./"`) — the default.** This is what the
plugin scaffolds and what the agent flows write:

```text
horizon-template/
└── <template-name>/
    ├── <template-name>.horizon-template.json   (source: "./")
    └── content.json   (or content.njk)
```

**Pattern B — content in a named subdirectory (`source: "./<template-name>"`) — the alternative.**
Use only when a single feature directory groups multiple templates (seen in some existing
project repositories). The subdirectory name must match the template `name` field exactly:

```text
horizon-template/
└── <feature-dir>/
    ├── <template-name>.horizon-template.json   (source: "./<template-name>")
    └── <template-name>/
        └── content.json   (or content.njk)
```

### HorizonTemplate metadata schema

```json
{
  "metadata": { "type": "HorizonTemplate" },
  "name": "schedule-plan-list-template",
  "description": "List page for Schedule Plans",
  "kind": "PAGE_LAYOUT",
  "source": "./"
}
```

| Property | Type | Required | Notes |
|---|---|---|---|
| `metadata.type` | string | Yes | Always `"HorizonTemplate"` |
| `name` | string | Yes | Must equal the page's `templateName` and the template directory name |
| `description` | string | Yes | Short description (may be `""`) |
| `kind` | string | Yes | `"PAGE_LAYOUT"` or `"PAGE_EXTENDED"` — see flavor table above |
| `source` | string | Yes | `"./"` (flat, default) or `"./<template-name>"` (subdirectory alternative) |

> **Naming convention**: template `name` carries a `-template` suffix to distinguish it from the
> page slug (slug `schedule-plan-list` → templateName `schedule-plan-list-template`). This is a
> convention, not a requirement — match whatever the project already uses.

### content.njk (Direct Nunjucks)

Two valid forms:

**Form 1 — bare `<platform-component>` (simplest)**

```njk
<platform-component
  package-name="<your-bundle-package-name>"
  name="<RegisteredComponentName>">
</platform-component>
```

**Form 2 — Nunjucks `extends` with a base layout (common in real projects)**

```njk
{% extends "base-listview" %}

{% set title = "Schedule Plans" %}
{% set resource_name = "SchedulePlans" %}

{% block body %}
  <platform-component
    package-name="<package-name>"
    name="<ComponentName>">
  </platform-component>
{% endblock %}
```

```njk
{% extends "base-recordview" %}

{% block header %}{% endblock header %}

{% block body %}
  <platform-component
    package-name="<package-name>"
    name="<ComponentName>">
  </platform-component>
{% endblock %}
```

| Base template | Use for |
|---|---|
| `base-listview` | List pages — provides standard list chrome and title |
| `base-recordview` | Record view/edit pages — provides record context layout |

Additional attributes on `<platform-component>` (e.g. `ptr=`, `label-position=`) are passed as
props to the component.

---

## Project File Structure

The plugin scaffolds a **flat** layout — pages directly under `horizon-page/`, templates directly
under `horizon-template/<template-name>/`:

```text
<project-root>/
├── SPEC.md
├── horizon-page/
│   └── <slug>.horizon-page.json
└── horizon-template/
    └── <template-name>/
        ├── <template-name>.horizon-template.json    # source: "./"
        └── content.json   (or content.njk)
```

> The deploy command expects `horizon-page/*.horizon-page.json` — the flat layout above. Some
> existing repositories use feature subdirectories; that is a project-level convention, not the
> plugin scaffold.

### Naming conventions

- **Page file**: `<slug>.horizon-page.json` — kebab-case, stem matches the `slug` field
- **Template metadata file**: `<template-name>.horizon-template.json` — stem is the template `name`
- **Template directory**: named after the template `name`
- **Content file**: `content.json` (Page Builder / Custom Page Builder) or `content.njk`
  (Direct Nunjucks)
- Page Builder pages follow: page `page-builder-<resource>`, template
  `page-builder-<resource>-template`

---

## Deploy

Deployment is explicit via `/horizon-page:deploy --alias <alias>` — see that command for the full
workflow (pre-flight checks, package mode vs per-artifact upsert, and the production
register→deploy-registered gate). After deploy, the page is available at `/platform/page/<slug>`.

---

## Quick Local Test (No Deploy)

To preview a page before deploying:

1. Navigate to **Settings > Developer tools > Platform pages**.
2. Click **Create page**: pick the matching `pageType`, and paste the `content.njk` or
   `content.json` body as the template content.
3. Open the page at `/platform/page/<slug>`.

For Custom Page Builder and Direct Nunjucks pages: run `yarn run preview` in the component bundle,
set the preview port in Horizon State Manager, and load the page — the local build takes
precedence over any deployed version.

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Page metadata rejected on deploy | Deprecated `label`/`path`/`componentBundleName` shape | Use `name`/`templateName`/`slug`/`published`/`pageType` |
| Page doesn't appear | `published: false` or slug mismatch | Set `published: true`; confirm slug |
| Template not found | `templateName` ≠ template `name` | Make them match exactly |
| Component doesn't render (PAGE_EXTENDED) | Wrong `package-name`/`name` in `content.njk` | Match `registerComponent(...)` arguments exactly |
| Page Builder content not rendering | Malformed `content.json` | Validate against the `page-builder` skill schema |
| Template content not found at deploy | `source` doesn't match content location | `source: "./"` with content beside the metadata file (or `"./<template-name>"` with a matching subdirectory) |
