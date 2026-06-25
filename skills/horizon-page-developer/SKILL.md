---
name: horizon-page-developer
description: Core skill for authoring and deploying Skedulo Horizon platform pages. Covers HorizonPage and HorizonTemplate artifact schemas, the three page authoring flows (Page Builder, Custom Page Builder, and Direct Nunjucks), file structure conventions, and deploy commands.
---

# Horizon Page Developer

A **Horizon page** is a deployable artifact on the Skedulo Pulse Platform that maps a URL slug to a
rendered template. Every page consists of two artifacts:

1. **`HorizonPage`** — metadata file: links a slug + display name to a `HorizonTemplate` by name.
2. **`HorizonTemplate`** — template directory: defines what the page renders.

## Two Page Authoring Flows

| Flow | Template `kind` | Content file | Use for |
|---|---|---|---|
| **Page Builder** | `PAGE_LAYOUT` or `PAGE_EXTENDED` | `content.json` (PageConfiguration JSON) | Pages composed from Page Builder components — standard PB components and/or custom registered components. Admins can configure via the gear icon. |
| **Direct Nunjucks** | `PAGE_EXTENDED` | `content.njk` (Nunjucks template) | Render a component directly via Nunjucks, bypassing Page Builder entirely. No admin UI. |

### Which flow to use

**Prefer Page Builder (`content.json`) unless you have a specific reason not to.** Page Builder can
embed both standard platform components and custom registered React components (from any bundle that
has been deployed to the tenant and registered via `registerComponent(...)`). Choosing Page Builder
keeps the page configurable via the admin gear icon.

Use **Direct Nunjucks (`content.njk`)** only when the ticket/requirements explicitly request it, OR
when one of these technical conditions applies:
- The component is not registered with Page Builder (no `registerComponent(...)` call), OR
- You need Nunjucks base-template inheritance (`{% extends "base-listview" %}` etc.) for standard chrome

If the ticket does not mention Nunjucks or `content.njk`, default to Page Builder.

### Which `kind` to use

| `kind` | Use for |
|---|---|
| `PAGE_LAYOUT` | Standard typed pages: `type: "object_record"`, `"list"`, or `"create"` |
| `PAGE_EXTENDED` | Non-standard pages: `type: "custom"` or any Direct Nunjucks (`content.njk`) page |

> `PAGE_LAYOUT` and `PAGE_EXTENDED` with `content.json` both support custom registered components —
> the difference is the page type, not the component type.

> **Once you've decided on a flow, go to the `page-builder` skill for all implementation.** It has
> the full `content.json` schema, component library, Nunjucks templating, and deployment patterns.
> This skill covers only artifact schemas (HorizonPage / HorizonTemplate) and flow/kind selection.

---

## Embedding an Existing horizon-component Bundle

When a component bundle has already been built (via the `horizon-component` plugin) and you need to
create a page that hosts it, follow these steps before authoring any artifacts.

### Step 1 — Find the registered package name and component name

Look in the bundle's `src/index.ts` for `registerComponent(...)` calls:

```typescript
// src/index.ts
registerComponent('booking-grid', 'BookingGrid', BookingGridComponent, { ... })
//                 ^^^^^^^^^^^^   ^^^^^^^^^^^
//                 packageName    component name
```

- **`packageName`** (1st arg) — use this as `"packageName"` in content.json sections, or as `package-name` in `<platform-component>`
- **`component name`** (2nd arg) — use this as `"component"` in content.json sections, or as `name` in `<platform-component>`

If `src/index.ts` has no `registerComponent(...)` call, the component is **not registered with Page
Builder** — use Direct Nunjucks (`content.njk`) instead.

### Step 2 — Confirm the bundle package name

Cross-check against the bundle's `package.json` `"name"` field. The `registerComponent` first argument
should match (or be a scoped subset of) this value.

### Step 3 — Choose the flow

| Condition | Flow |
|---|---|
| `registerComponent(...)` exists | Page Builder (`content.json`) — embed as `{ "packageName": "...", "component": "..." }` |
| No `registerComponent(...)` | Direct Nunjucks (`content.njk`) — embed as `<platform-component package-name="..." name="...">` |

### Step 4 — Author the page artifacts

For **Page Builder** — embed the component inside a tab's `children` (or directly as a tab):

```json
{
  "name": "My Component",
  "packageName": "booking-grid",
  "component": "BookingGrid"
}
```

For **Direct Nunjucks** — use the `<platform-component>` tag:

```njk
<platform-component
  package-name="booking-grid"
  name="BookingGrid">
</platform-component>
```

See the `page-builder` skill for the full `content.json` structure around these embeddings.

### Project structure when bundle and page live in the same repo

```text
src/
├── horizon-component-bundles/
│   └── <bundle-name>/
│       ├── src/
│       │   ├── <ComponentName>.tsx
│       │   └── index.ts              # registerComponent(...) calls live here
│       └── package.json
├── horizon-page/
│   └── <slug>.horizon-page.json
└── horizon-template/
    └── <template-name>/
        ├── <template-name>.horizon-template.json
        └── content.json   (or content.njk)
```

---

## HorizonPage Artifact

**File**: `horizon-page/<slug>.horizon-page.json`

```json
{
  "metadata": {
    "type": "HorizonPage"
  },
  "name": "Schedule Plans",
  "templateName": "schedule-plan-list",
  "slug": "schedule-plan-list",
  "published": true,
  "pageType": "LIST"
}
```

### Properties

| Property | Type | Required | Notes |
|---|---|---|---|
| `metadata.type` | string | Yes | Always `"HorizonPage"` |
| `name` | string | Yes | Display name shown in the admin UI |
| `templateName` | string | Yes | Must match a `HorizonTemplate`'s `name` field exactly |
| `slug` | string | Yes | Unique URL identifier — page lives at `/platform/page/<slug>` |
| `published` | boolean | Yes | `true` makes the page live immediately after deploy |
| `pageType` | string | Yes | One of the values below |
| `description` | string | No | Optional display description — shown in admin UI |

### Valid `pageType` Values

| Value | Use for |
|---|---|
| `LIST` | A platform-templated list page — renders the object's **default HorizonListConfig** as-is, with no page-level customization. See the recommendation below before choosing this. |
| `VIEW` | A read-only record view page |
| `EDIT` | A record edit page |
| `CREATE` | A record create page |
| `RELATED_LIST` | A related-list embedded under a record |
| `COLUMN_EDITOR` | A list column-configuration page |
| `PAGE_BUILDER` | A declarative Page Builder page (use the `page-builder` skill) |
| `CUSTOM` | A fully custom page — use when none of the standard types applies (e.g. embedded grids, custom modal flows, booking views) |

> Pick `pageType` to match the page's purpose. A record view uses `VIEW`. `PAGE_BUILDER` is only for
> declarative Page Builder pages. Use `CUSTOM` only when no standard type fits — it carries no implicit
> layout or context injection.

> **For list pages, prefer a Page Builder page with a `ListView` component** (`pageType: "PAGE_BUILDER"`,
> `kind: "PAGE_LAYOUT"`, `content.json`) over `pageType: "LIST"`. The Page Builder + ListView approach
> lets you add a custom header, extra sections, and per-page column overrides, and you can either
> **inline the `listConfig`** or **leave it blank to inherit the object's default `HorizonListConfig`**
> (the artifact the `horizon-list-config` plugin deploys). Use `pageType: "LIST"` only for a bare list
> that renders the default config with zero page-level customization. See the `page-builder` skill's
> **ListView Component** section.

### DEPRECATED — Never Generate This Shape

```json
{
  "metadata": { "type": "HorizonPage" },
  "name": "scheduleplan-list",
  "label": "Schedule Plans",
  "path": "/schedule-plans",
  "componentBundleName": "schedule-plans-list"
}
```

Old scaffolds emitted `label`, `path`, and `componentBundleName`. **This shape is invalid** and will
not deploy. Map old fields to the correct schema:

| Deprecated | Correct |
|---|---|
| `label` | `name` |
| `path` | `slug` (URL becomes `/platform/page/<slug>`) |
| `componentBundleName` | Use `templateName` + a template that embeds the component via `<platform-component>` |
| — | Add `published` (boolean) and `pageType` |

---

## HorizonTemplate Artifact

A template sits in a directory and contains a metadata JSON file plus a content file (`content.json`
or `content.njk`). The `source` field in the metadata controls where the content file lives relative
to the `.horizon-template.json` file.

### `source` field — two valid patterns

**Pattern A — content in a named subdirectory (default, most common)**

```text
horizon-template/
└── <feature-dir>/
    ├── <template-name>.horizon-template.json   (source: "./<template-name>")
    └── <template-name>/
        └── content.njk   (or content.json)
```

Use this when a feature directory groups multiple templates, or as the default for new templates. The
subdirectory name **must match** the template `name` field (and the `.horizon-template.json` filename
stem).

**Pattern B — content at the directory root (`source: "./"`)** 

```text
horizon-template/
└── <feature-dir>/
    ├── <template-name>.horizon-template.json   (source: "./")
    └── content.njk   (or content.json)
```

Use only when the feature directory holds exactly one template and a subdirectory would add no value.
Less common in practice.

### HorizonTemplate metadata schema

```json
{
  "metadata": { "type": "HorizonTemplate" },
  "name": "schedule-plan-list-template",
  "description": "List page for Schedule Plans",
  "kind": "PAGE_LAYOUT",
  "source": "./schedule-plan-list-template"
}
```

| Property | Type | Required | Notes |
|---|---|---|---|
| `metadata.type` | string | Yes | Always `"HorizonTemplate"` |
| `name` | string | Yes | Must equal the value in the page's `templateName` field |
| `description` | string | Yes | Short description (may be empty string `""`) |
| `kind` | string | Yes | `"PAGE_LAYOUT"` for standard typed PB pages; `"PAGE_EXTENDED"` for custom-type PB pages or Direct Nunjucks |
| `source` | string | Yes | `"./<name>"` (subdirectory) or `"./"` (root) — see patterns above |

> **Naming convention**: template `name` commonly carries a `-template` suffix to distinguish it from
> the page slug. E.g. page slug `schedule-plan-list` → `templateName: "schedule-plan-list-template"`.
> This is a convention, not a requirement — match whatever the project already uses.

### content.json (Page Builder — `kind: "PAGE_LAYOUT"` or `"PAGE_EXTENDED"`)

A `PageConfiguration` JSON object. Both standard platform components (`packageName: "page-builder"`,
`"listview"`) and **custom registered components** from any deployed bundle can appear anywhere in
`sections`. The component just needs to be registered via `registerComponent(...)` and deployed.

```json
{
  "id": "booking-grid",
  "template": "header-body",
  "type": "custom",
  "resourceName": "",
  "sections": {
    "header": {
      "packageName": "page-builder",
      "component": "PageHeader",
      "properties": { "title": "Schedule New Job" }
    },
    "tabs": [
      {
        "name": "Container",
        "packageName": "page-builder",
        "component": "Container",
        "route": "container",
        "properties": {
          "children": [
            {
              "name": "Booking Grid",
              "packageName": "booking-grid",
              "component": "BookingGrid"
            }
          ]
        }
      }
    ]
  }
}
```

> `packageName` in sections refers to the **bundle package name**, not the Page Builder package.
> Any component registered with `registerComponent('booking-grid', 'BookingGrid', ...)` is addressable
> as `{ "packageName": "booking-grid", "component": "BookingGrid" }` in content.json.

See the `page-builder` skill for the full schema, component library, and tab/section structure. For non-`custom` pages, set `resourceName` to the object's display name (PascalCase, single space between words — e.g. `"Schedule Plan"`, not `"scheduleplan"`); see that skill's **ResourceName Casing** section.

### content.njk (Direct Nunjucks — `kind: "PAGE_EXTENDED"`)

Two valid forms:

**Form 1 — bare `<platform-component>` (simplest)**

```njk
<platform-component
  package-name="<your-bundle-package-name>"
  name="<RegisteredComponentName>">
</platform-component>
```

**Form 2 — Nunjucks `extends` with base layout (common in real projects)**

Most production templates extend a base layout. Choose the base that matches the page type:

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

- `package-name` — the bundle's package name (first argument to `registerComponent(...)`)
- `name` — the registered component name (second argument to `registerComponent(...)`)
- Additional attributes (e.g. `ptr=`, `label-position=`) are passed as props to the component

---

## Project File Structure

The `horizon-page` plugin scaffolds a **flat** layout — pages directly under `horizon-page/`,
templates directly under `horizon-template/<template-name>/`:

```text
<project-root>/
├── horizon-page/
│   ├── <slug-1>.horizon-page.json
│   └── <slug-2>.horizon-page.json
└── horizon-template/
    ├── <template-1>/
    │   ├── <template-1>.horizon-template.json    # source: "./"
    │   └── content.json   (or content.njk)
    └── <template-2>/
        ├── <template-2>.horizon-template.json    # source: "./"
        └── content.json   (or content.njk)
```

> The deploy command (`/horizon-page:deploy`) expects `horizon-page/*.horizon-page.json` — the flat
> layout above. CX project repositories sometimes use feature subdirectories (`horizon-pages/<feature>/`)
> but this is a project-level convention, not the plugin scaffold.

### Naming Conventions

- **Page file**: `<slug>.horizon-page.json` — kebab-case, matches the `slug` field
- **Template metadata file**: `<template-name>.horizon-template.json` — the stem is the template `name`
- **Template `name`**: typically `<slug>-template` (adds `-template` suffix to distinguish from the slug)
  - E.g. slug `wellbe-accounts-list` → templateName `wellbe-accounts-list-template`
  - The suffix is a convention; follow whatever the project already uses
- **Content subdirectory**: same name as the template `name` field (and the `.horizon-template.json` stem)
- **Content file**: `content.json` for `PAGE_LAYOUT` and `PAGE_EXTENDED` (Page Builder); `content.njk` for `PAGE_EXTENDED` (Direct Nunjucks only)

For Page Builder pages, naming follows: page `page-builder-<resource>`, template `page-builder-<resource>-template`.

---

## Deploy

```bash
# Upsert a single page artifact
sked artifacts horizon-page upsert -a <alias> -f horizon-page/<slug>.horizon-page.json

# Deploy the whole package (pages + templates together)
sked package deploy local -p .

# Production: register first, then deploy
sked package register -p .
sked package deploy registered -a <alias> -p <package-name> --packageVersion <v>
```

After deploy, the page is available at `/platform/page/<slug>`.

---

## SPEC.md Structure for Horizon Page Projects

```text
# Horizon Page Progress: <project-name>

## Status
- Phase: [Planning | Implementation | Review | Complete]
- Last Updated: <timestamp>
- Last Agent: <agent-name>

## Pages to Build

### Page Builder Pages
- [ ] PB1: <resource> list page — <slug>
- [ ] PB2: <resource> detail page — <slug>

### Custom Page Builder Pages (kind: PAGE_EXTENDED, content.json)
- [ ] CPB1: <name> page — <slug>

### Direct Nunjucks Pages (kind: PAGE_EXTENDED, content.njk)
- [ ] NJK1: <component-name> page — <slug>

## Implementation Notes
- Tenant alias: <alias or "not yet set">
- Bundle package name (Custom Page Builder / Direct Nunjucks only): <package-name>

## Completed Pages
- [x] PB1: ...

## Latest Review
(appended by review agent)
```

---

## Quick Local Test (No Deploy)

To preview a page before deploying:

1. Navigate to **Settings > Developer tools > Platform pages**.
2. Click **Create page** and fill in the form:
   - **Page Type**: pick the matching `pageType` value
   - **Template Content**: paste the `content.njk` or `content.json` body
3. Open the page at `/platform/page/<slug>`.

For Custom Page Builder and Direct Nunjucks pages: run `yarn run preview` in the component bundle, set the preview port in
Horizon State Manager, and load the page — the local build takes precedence over any deployed version.

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Page metadata rejected on deploy | Deprecated `label`/`path`/`componentBundleName` shape | Use correct schema: `name`/`templateName`/`slug`/`published`/`pageType` |
| Page doesn't appear | `published: false` or slug mismatch | Set `published: true`; confirm slug matches intended URL |
| Template not found | `templateName` doesn't match template `name` | Verify the page's `templateName` equals the template directory/metadata `name` exactly |
| Component doesn't render (PAGE_EXTENDED) | Wrong `package-name`/`name` in `content.njk` | Match `registerComponent(...)` arguments exactly |
| Page Builder content not rendering (PAGE_LAYOUT) | Malformed `content.json` | Validate PageConfiguration JSON against `page-builder` skill schema |
| Template content not found at deploy | `source` path doesn't match content location | Ensure `source: "./<template-name>"` and the subdirectory exists with that exact name |
