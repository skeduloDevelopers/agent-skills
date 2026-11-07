---
name: page-builder
description: Use when authoring or editing a Page Builder content.json for a Skedulo Horizon page — adding a tab, building a list page with custom columns, configuring ListView listConfig or relationshipResolution, or composing PageHeader, FieldLayout, RelatedList and Container components and their Nunjucks templates. Covers the PageConfiguration schema, the component library, and ResourceName casing. HorizonPage and HorizonTemplate artifact schemas live in the horizon-page-developer skill.
---

# Page Builder Skill

**Page Builder** is the declarative page system on the Skedulo Horizon platform. A Page Builder
page is defined by a **PageConfiguration** JSON (`content.json` inside a `HorizonTemplate`) that
composes registered UI components into a header + tabs layout — no React required.

This skill is the authoring reference for `content.json`: the PageConfiguration schema, the
component library, Nunjucks templating, and list configuration. Artifact schemas
(HorizonPage / HorizonTemplate) and flavor selection live in the `horizon-page-developer` skill.
Full-page examples live in [references/page-patterns.md](references/page-patterns.md).

> Page Builder is currently **open beta** — pre-GA, subject to change.

---

## Finding Object Fields and Relationships

Use the **GraphQL Schema MCP Server** to explore the data model before referencing any field:

- List objects and top-level fields: `mcp__plugin_horizon-page_graphql-schema__search_schema`
- Field details for a type: `mcp__plugin_horizon-page_graphql-schema__introspect_type`
  (e.g. `type_name: "Jobs"`)

This is the canonical source for exact field names (e.g. `JobStatus`, not `Status`), relationship
definitions (e.g. `JobAllocations → Resource`), and nested paths for
`relationshipResolution.allow`.

---

## PageConfiguration Structure

```json
{
  "id": "page-builder-job",
  "template": "tabs",
  "type": "object_record",
  "resourceName": "Jobs",
  "enableOverride": true,
  "sections": {
    "header": {
      "packageName": "page-builder",
      "component": "PageHeader",
      "properties": {
        "title": "{{ Name if Name != null else UID }}"
      }
    },
    "tabs": [
      {
        "name": "Details",
        "packageName": "page-builder",
        "component": "FieldLayout",
        "route": "details",
        "properties": {
          "displayMode": "showAll",
          "chromeless": false
        }
      }
    ]
  }
}
```

### Root properties

| Property | Type | Required | Notes |
|---|---|---|---|
| `id` | string | Yes | Must match the page slug |
| `template` | string | Yes | `"tabs"` or `"header-body"` — see table below |
| `type` | string | Yes | `"object_record"`, `"list"`, `"create"`, or `"custom"` |
| `resourceName` | string | Yes | Object display name (see **ResourceName Casing**); `""` for `type: "custom"` |
| `enableOverride` | boolean | No | Recommend `true` — lets admins create an override template (`<slug>-override`) instead of editing the base; if a new base ships, they can keep or reset their customizations |
| `sections` | object | Yes | `header` (optional PageComponent) + `tabs` (required array) |

### The two templates

Every page uses the same `sections` structure; the `template` picks the layout engine:

| Template | Type | Use case | URL sync | Record context |
|---|---|---|---|---|
| `tabs` | object_record | Detail pages with multiple info tabs | Yes | Yes (`record` + `recordContext` props injected) |
| `header-body` | list, create, custom | List/create/custom pages | No | No |

Use `"custom"` with `"template": "header-body"` and `"resourceName": ""` when the page manages its
own data (settings dashboards, booking grids, embedded custom components).

**Key points:**

- The `tabs` array is **always** required, even for single-tab layouts
- Each tab should have a `route` property (required for `tabs` template, optional for
  `header-body`) — the URL becomes `/p/<slug>/<route>`
- `showIf` (Nunjucks boolean expression, e.g. `"{{ JobStatus === 'Completed' }}"`) gives a tab or
  component conditional visibility
- Tabs accept an optional `roles` array to restrict visibility by user role — if omitted, the tab
  is visible to all roles:

```json
{
  "name": "Admin Settings",
  "packageName": "page-builder",
  "component": "FieldLayout",
  "route": "admin",
  "roles": ["Administrator", "Scheduler"],
  "properties": { "displayMode": "showAll" }
}
```

- Any component accepts an optional `display` object for presentation: `mode` (`"Card"` /
  `"None"`), `columns` (1–12 on a 12-column grid, or `"Flexible"`), `collapsible` (`"Left"` /
  `"Right"` / `"None"`), `padding`

### Page type patterns

- **Detail page** (`object_record` + `tabs`): header with Nunjucks title, multiple tabs
  (`FieldLayout`, `RelatedList`, `Container`), each with a `route`
- **List page** (`list` + `header-body`): header with a Create `LinkButton`, one `ListView` tab —
  see **ListView Component** below
- **Create page** (`create` + `header-body`): header, one `CreateFieldLayout` tab

Full JSON for all three is in [references/page-patterns.md](references/page-patterns.md).

### ResourceName Casing

`resourceName` must match the object's **display name**: PascalCase, each word capitalized, with a
**single space between words** for multi-word objects — e.g. `"Schedule Plan"`, `"Shift Types"`,
`"Resource Region"`. Take the exact display name from the schema; do not invent word boundaries.

- Never lowercase or concatenate: `"scheduleplan"`, `"schedule plan"`, and `"SchedulePlan"` are all
  wrong — use `"Schedule Plan"`.
- Standard objects keep their special plural casing: always `"Jobs"` and `"Resources"`.
- This is separate from the page `slug` / file names, which stay lowercase-kebab (slug
  `page-builder-schedule-plan-list`, resourceName `"Schedule Plan"`).
- Use the same `resourceName` everywhere on the page — the page-level value and any
  component-level value (e.g. `CreateFieldLayout`) must match exactly.

---

## Nunjucks in Properties

All string properties are processed through **Nunjucks** before reaching components:

```json
{
  "properties": {
    "title": "{{ Name if Name != null else UID }}",
    "code": "<div>Customer: {{ Account.Name }}</div>",
    "subtitle": "Created by {{ $User.Name }} on {{ CreatedDate }}"
  }
}
```

**Available variables:**

- `{{ FieldName }}` — any field from the record. **All Skedulo object properties use uppercase
  names** (`Name`, `Description`, `JobStatus`) — use the exact casing from the schema.
- `{{ $User.Name }}`, `{{ $User.FirstName }}`, `{{ $User.Email }}`, `{{ $User.Roles }}` — current
  user
- `{{ _.record.primaryKeyValue }}` — the row's record UID inside list column templates (for
  building links)
- Filters and conditionals: `{{ Total | number(decimals=2) }}`,
  `{{ CreatedDate | dateFormat('MMM dd, YYYY') }}`, `{% if ... %}...{% endif %}`

**JavaScript is NOT supported** in templates — Nunjucks and HTML only.

**Array relationships**: loop with conditions to filter and access nested properties:

```njk
{% for allocation in JobAllocations %}{% if allocation.Status != 'Cancelled' and allocation.Status != 'Declined' %}{{ allocation.Resource.Name }}{% if not loop.last %}, {% endif %}{% endif %}{% endfor %}
```

Nested access like `allocation.Resource.Name` only works when every level of the path is
whitelisted in `relationshipResolution.allow` — see **ListView Component**.

---

## Component Library

### Code

Render custom HTML, Nunjucks, or embedded platform components — custom headers, formatted text
(Tailwind `tw-` prefix classes), dynamic content:

```json
{
  "packageName": "page-builder",
  "component": "Code",
  "name": "Custom HTML Header",
  "properties": {
    "code": "<div class='tw-text-2xl tw-font-bold'>{{ Name }}</div>"
  }
}
```

Embed other components inside `code` via `<platform-component>` tags:

```html
<platform-component
  package-name="icons"
  name="Icon"
  icon="briefcase"
  size="20"
></platform-component>
```

### Icon

500+ BoxIcons:

```json
{
  "packageName": "icons",
  "component": "Icon",
  "name": "Briefcase Icon",
  "properties": { "iconName": "briefcase", "size": 20, "color": "#666" }
}
```

Common icons: home, menu, search, cog, grid, dashboard, user, edit, trash, save, copy, calendar,
briefcase, building, car, plane, check, error, chat, phone, plus, minus, chevronLeft, chevronRight.

### Container

Multi-column layouts and component grouping. **Use `"Container"`, NOT `"LayoutContainer"`** — the
latter is not a registered component name.

```json
{
  "packageName": "page-builder",
  "component": "Container",
  "name": "Layout Container",
  "properties": {
    "displayDirection": "row",
    "gap": 16,
    "padding": 16,
    "backgroundColor": "gray",
    "children": [
      { "packageName": "page-builder", "component": "FieldLayout",
        "properties": { "displayMode": "showAll", "chromeless": true },
        "display": { "columns": 6, "mode": "Card" } },
      { "packageName": "page-builder", "component": "RelatedList",
        "properties": { "resourceName": "History", "query": "entityId:{{ UID }}" },
        "display": { "columns": 6, "mode": "Card" } }
    ]
  }
}
```

Properties: `displayDirection` (`"row"`/`"column"`), `gap`, `padding`, `children`, `distribute`
(`"start"`/`"center"`/`"end"`/`"space-between"`/`"stretch"`), `align`, `backgroundColor`
(`"transparent"`/`"white"`/`"gray"` — use gray by default), `size` (`"fill"`/`"fit"`).

Column widths use the 12-column grid on each child's `display.columns`: two columns → `6` each,
three columns → `4` each.

### FieldLayout

Display fields from the current record:

```json
{
  "packageName": "page-builder",
  "component": "FieldLayout",
  "name": "Details",
  "properties": { "displayMode": "showAll", "chromeless": false }
}
```

- `displayMode`: `"showAll"`, `"custom"` (with a `fields` array), or `"organizeManually"` (with
  full field definitions — see [references/page-patterns.md](references/page-patterns.md))
- `chromeless`: **set `true` whenever the FieldLayout sits inside a Container** — hides its own
  border/padding so the container's layout controls presentation

### PageHeader

Title, subtitle (both support Nunjucks and HTML), and action buttons:

```json
{
  "packageName": "page-builder",
  "component": "PageHeader",
  "properties": {
    "title": "Jobs",
    "subtitle": "Status: {{ JobStatus }}",
    "actions": [
      {
        "packageName": "page-builder",
        "component": "LinkButton",
        "properties": { "label": "Create new", "type": "primary", "path": "create" }
      }
    ]
  }
}
```

### LinkButton

Navigation button:

```json
{
  "packageName": "page-builder",
  "component": "LinkButton",
  "properties": {
    "label": "Back to Jobs",
    "type": "transparent-primary",
    "path": "/p/jobs",
    "leadingIcon": "chevronLeft"
  }
}
```

`type`: `"primary"`, `"secondary"`, or `"transparent-primary"`. `path` may be absolute (`/p/jobs`)
or relative (`create`).

### RelatedList

Related records with filtering and search:

```json
{
  "packageName": "page-builder",
  "component": "RelatedList",
  "name": "Related History",
  "properties": {
    "resourceName": "History",
    "query": "entityId:{{ UID }}",
    "columns": ["CreatedDate", "CreatedBy"],
    "sorting": ["-CreatedDate"],
    "hideSavedViews": true
  }
}
```

**`query` vs `queryOverride`:**

- **`query`** (preferred): the filter users can modify. Escaped filter syntax:
  - Is: `"query": "JobStatus:Dispatched"`
  - One of: `"query": "JobStatus:$in\\[\\\"Pending\\ Allocation\\\",\\\"Pending\\ Dispatch\\\"\\]"`
  - Is not: `"query": "-JobStatus:Pending\\ Allocation"`
  - Not one of: `"query": "-JobStatus:$in\\[\\\"Pending\\ Allocation\\\",\\\"Queued\\\"\\]"`
- **`queryOverride`** (locked baseline): users can add filters on top but cannot remove this
  constraint. Use only when the filter must be enforced. Default to `query`.

### ListView Component

Display a list of records with custom columns and efficient relationship resolution.

> **This is the way to build a list page** — a Page Builder page (`pageType: "PAGE_BUILDER"`,
> `kind: "PAGE_LAYOUT"`, `content.json`, content `type: "list"`) with a `ListView` in
> `sections.tabs` — **not `pageType: "LIST"`**. A `pageType: "LIST"` page only renders the
> object's default `HorizonListConfig` with no page-level customization; the Page Builder +
> ListView approach adds a custom header, extra sections, and per-page columns on the same page.
> Reserve `pageType: "LIST"` for a bare list that renders the default config unchanged.

**Two ways to supply the columns:**

1. **Inline `listConfig`** (below) — columns, ordering, and per-column Nunjucks templates directly
   on the ListView. Self-contained.
2. **Leave `listConfig` blank/omitted** — the ListView **inherits the object's default
   `HorizonListConfig`** (the artifact the `horizon-list-config` plugin deploys for that object).
   Use this when the page should track the object's standard list columns rather than pin its own.

> **Inline `listConfig` vs the `HorizonListConfig` artifact** — same Nunjucks templating,
> different packaging. Inline `listConfig.columns` is a **map** (`id → { title, template }`) with
> templates embedded as strings. A `HorizonListConfig` artifact's `columns` is an **array**
> (`[{ id, title, file }]`) with templates in separate `.njk` files plus
> `objectName`/`name`/`source`. A blank inline `listConfig` falls back to the deployed artifact.

```json
{
  "packageName": "listview",
  "component": "ListView",
  "name": "Jobs List",
  "properties": {
    "resourceName": "Jobs",
    "listConfig": {
      "columns": {
        "PageBuilder-Item": {
          "title": "Description",
          "template": "<brz-link href=\"/p/jobs/{{_.record.primaryKeyValue}}\">{{Description or UID}}</brz-link>"
        },
        "column-status": {
          "title": "Status",
          "template": "{{ JobStatus }}"
        }
      },
      "ordering": ["PageBuilder-Item", "column-status"],
      "depth": 1,
      "relationshipResolution": {
        "allow": ["CreatedBy", "CreatedBy.userAvatar"]
      }
    },
    "columns": ["PageBuilder-Item", "column-status"],
    "sorting": ["-CreatedDate"]
  }
}
```

To inherit the default `HorizonListConfig` instead, omit `listConfig` (or set it to `{}`):

```json
{
  "packageName": "listview",
  "component": "ListView",
  "name": "Jobs List",
  "properties": {
    "resourceName": "Jobs",
    "sorting": ["-CreatedDate"]
  }
}
```

**`depth`** — how many levels of related objects are fetched. Default to `1` (main object fields;
lightest call). Use `2` only when you need direct relationships not fetched by default. Higher
depth = heavier API calls; use the lowest depth that satisfies your columns.

**`relationshipResolution.allow`** — the whitelist that controls which nested relationships are
fetched. To access nested properties in your Nunjucks templates, you **must whitelist every level
of the relationship path**:

```jsonc
"relationshipResolution": {
  "allow": [
    "JobAllocations",              // Level 1: the array relationship itself
    "JobAllocations.Resource",     // Level 2: the nested object
    "JobAllocations.Resource.Name" // Level 3: the specific field to access
  ]
}
```

Without all three paths whitelisted, `allocation.Resource.Name` won't be available in your
template — **even with higher `depth` values**. Missing any level silently yields empty output.

The whitelist also prevents circular references (Jobs → Account → Jobs → …), keeps API calls
predictable, and avoids heavy payloads on large datasets — always specify it when columns
reference nested fields (`Account.Name`, `CreatedBy.userAvatar`, `Resource.FirstName`).

Optional: `displayedActions: { "showActions": false, "displayedActions": [] }` controls row
actions.

### CreateFieldLayout

Form for creating new records (create pages only):

```json
{
  "packageName": "page-builder",
  "component": "CreateFieldLayout",
  "name": "Create Form",
  "properties": { "resourceName": "Jobs", "displayMode": "showAll" }
}
```

---

## Partial Updates vs Full Configuration

When modifying existing pages, **always prefer partial updates** — full configuration only when
creating pages from scratch.

**TabUpdate** — add or modify a tab:

```json
{
  "type": "tab",
  "operation": "add",
  "index": 2,
  "component": {
    "packageName": "page-builder",
    "component": "RelatedList",
    "name": "Related Records",
    "properties": { "resourceName": "History", "query": "parentId:{{ UID }}" }
  }
}
```

**HeaderUpdate** — replace the entire header:

```json
{
  "type": "header",
  "component": {
    "packageName": "page-builder",
    "component": "PageHeader",
    "properties": { "title": "{{ Name }}" }
  }
}
```

Multiple updates go in one JSON array.

---

## Learn More

- **[references/page-patterns.md](references/page-patterns.md)** — complete detail/list/create
  `content.json` examples and multi-column layout recipes
- **[Page Builder Home](https://developer.skedulo.com/user-guides/admin-and-config/admin-and-config-webapp/page-builder/)** — official Skedulo guides
- **[List View Customization](https://docs.skedulo.com/developer-guides/customize-and-extend/list-view-pages/)** — list view feature documentation
- **[Advanced Column Configuration](https://developer.skedulo.com/developer-guides/customize-and-extend/list-view-pages/advanced-column-config/)** — column formatting with templates
- **Breeze V2 components** — use the `horizon-component` plugin for React component authoring
