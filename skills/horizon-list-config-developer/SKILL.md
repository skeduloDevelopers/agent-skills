---
name: horizon-list-config-developer
description: Core skill for authoring and deploying Skedulo HorizonListConfig artifacts. Covers the JSON schema, column Nunjucks template patterns, naming conventions, file structure, and deploy commands for configuring built-in Skedulo object list pages.
---

# Horizon List Config Developer

A **HorizonListConfig** defines the column layout and cell rendering for a built-in Skedulo object
list page (e.g. `/p/jobs`, `/p/resources`). It is independent of `HorizonPage` — it configures the
platform's default list views, not custom pages.

Each config consists of:
1. **A `.horizon-list-config.json` metadata file** — declares the object, columns, and ordering.
2. **A `source` subdirectory** — contains one Nunjucks `.njk` template file per column.

---

## HorizonListConfig Artifact Schema

**File**: `horizon-list-configs/<feature-dir>/<ObjectName>-DEFAULT_LIST.horizon-list-config.json`

```json
{
  "metadata": { "type": "HorizonListConfig" },
  "objectName": "Jobs",
  "name": "Default Jobs",
  "columns": [
    { "id": "Job",    "title": "Job",    "file": "Job-template.njk" },
    { "id": "Status", "title": "Status", "file": "Status-template.njk" },
    { "id": "Region", "title": "Region", "file": "Region-template.njk" }
  ],
  "ordering": ["Job", "Status", "Region"],
  "displayedActions": {
    "showActions": false,
    "displayedActions": []
  },
  "source": "./Jobs-DEFAULT_LIST"
}
```

### Properties

| Property | Type | Required | Notes |
|---|---|---|---|
| `metadata.type` | string | Yes | Always `"HorizonListConfig"` |
| `objectName` | string | Yes | Skedulo object name — matches the platform entity (e.g. `"Jobs"`, `"Resources"`, `"Contacts"`) |
| `name` | string | Yes | Display name — convention is `"Default <ObjectName>"` |
| `columns` | array | Yes | Ordered list of column definitions |
| `ordering` | array | Yes | Array of column `id` values in display order — must include every column `id` |
| `displayedActions.showActions` | boolean | Yes | Whether to show the actions panel on the list |
| `displayedActions.displayedActions` | array | Yes | Action objects — use `[]` unless specific actions are required |
| `source` | string | Yes | Always `"./<ObjectName>-DEFAULT_LIST"` — points to the column template subdirectory |

### Column object

| Property | Type | Notes |
|---|---|---|
| `id` | string | Unique identifier — use the field name (e.g. `"Name"`, `"JobStatus"`) or a dot-path for nested fields (`"Account.Name"`) |
| `title` | string | Column header displayed to users |
| `file` | string | Filename of the Nunjucks template in the `source` directory (e.g. `"Name-template.njk"`) |

> Use GraphQL Schema MCP (`mcp__plugin_horizon-list-config_graphql-schema__search_schema`,
> `mcp__plugin_horizon-list-config_graphql-schema__introspect_type`) to discover available fields and
> nested relationship paths for the target object.

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Feature directory | kebab-case | `jobs`, `contacts`, `resource-job-type-settings` |
| Config filename | `<ObjectName>-DEFAULT_LIST.horizon-list-config.json` | `Jobs-DEFAULT_LIST.horizon-list-config.json` |
| `objectName` field | Skedulo entity name (PascalCase, may include spaces) | `"Jobs"`, `"Job Type Modality Settings"` |
| `name` field | `"Default <ObjectName>"` | `"Default Jobs"` |
| `source` subdirectory | Same as config filename prefix | `./Jobs-DEFAULT_LIST` |
| Column template files | `<ColumnTitle>-template.njk` | `Job-template.njk`, `Status-template.njk` |

---

## File Structure

```text
horizon-list-configs/
└── <feature-dir>/
    ├── <ObjectName>-DEFAULT_LIST.horizon-list-config.json
    └── <ObjectName>-DEFAULT_LIST/
        ├── <Column1>-template.njk
        ├── <Column2>-template.njk
        └── ...
```

Example for Jobs:

```text
horizon-list-configs/
└── jobs/
    ├── Jobs-DEFAULT_LIST.horizon-list-config.json
    └── Jobs-DEFAULT_LIST/
        ├── Job-template.njk
        ├── Status-template.njk
        ├── Region-template.njk
        └── Scheduled-template.njk
```

---

## Column Template Patterns

Column templates are standalone Nunjucks files — **no `extends`**, no base template inheritance.
Each file renders a single cell for its column. The platform injects record fields and helpers as
template variables.

### Available variables

| Variable | Description |
|---|---|
| `{{ FieldName }}` | Any top-level field on the record (e.g. `{{ Name }}`, `{{ JobStatus }}`) |
| `{{ Relationship.Field }}` | Nested field via relationship (e.g. `{{ Account.Name }}`, `{{ PrimaryRegion.UID }}`) |
| `_.host.buildPlatformUrl('slug?uid=' + UID)` | Build a platform-relative URL (e.g. for navigation links) |
| `_.record.primaryKeyValue` | The record's primary key — use in URLs when `UID` is not available |

### Pattern 1 — Simple field display

```njk
{{ JobStatus }}
```

### Pattern 2 — Conditional with fallback

```njk
{% if Email %}
  <a href="mailto:{{ Email }}">{{ Email }}</a>
{% else %}
  <span style="color: #7d879c;">Not set</span>
{% endif %}
```

### Pattern 3 — Navigation link to a platform page

```njk
<a href="{{ _.host.buildPlatformUrl('jobs-view?uid=' + UID) }}">
  <b>{{ Name }}</b>
</a>
```

### Pattern 4 — Status badge with Breeze lozenge

```njk
{% if JobStatus == 'Complete' %}
  <brz-lozenge size="small" color="green" theme="solid">Complete</brz-lozenge>
{% elif JobStatus == 'Cancelled' %}
  <brz-lozenge size="small" color="red" theme="subtle">Cancelled</brz-lozenge>
{% else %}
  <brz-lozenge size="small" color="neutral" theme="subtle">{{ JobStatus }}</brz-lozenge>
{% endif %}
```

### Pattern 5 — Avatar with name (e.g. Created By)

```njk
<brz-row vertical-align="middle" style="--brz-row-spacing: var(--brz-spacing-2);">
  <brz-column>
    <brz-avatar
      label="{{ CreatedBy.Name }}"
      image-src="{{ CreatedBy.userAvatar.url }}"
      size="small"
      theme="subtle">
    </brz-avatar>
  </brz-column>
  <brz-column>{{ CreatedBy.Name }}</brz-column>
</brz-row>
```

### Pattern 6 — Nested relationship link

```njk
<a href="/l/accounts/{{ Account.UID }}" target="_blank">
  <b>{{ Account.Name }}</b>
</a>
```

### Breeze UI components available in templates

| Component | Use for |
|---|---|
| `<brz-lozenge>` | Status badges — props: `size`, `color`, `theme` |
| `<brz-avatar>` | User/resource avatars — props: `label`, `image-src`, `size`, `theme` |
| `<brz-link>` | Styled links — prop: `href` |
| `<brz-button>` | Action buttons — props: `element`, `href`, `button-type`, `compact`, `leading-icon` |
| `<brz-row>` / `<brz-column>` | Layout — props: `vertical-align`, CSS variable overrides |

> `brz-*` components use Breeze V2 design tokens. CSS custom properties like `--brz-spacing-2`,
> `--brz-color-neutral-600` are available for fine-tuning.

---

## Deploy

```bash
# Upsert a single list config artifact
sked artifacts horizon-list-config upsert -a <alias> -f horizon-list-configs/<feature-dir>/<ObjectName>-DEFAULT_LIST.horizon-list-config.json

# Deploy the whole package (all configs together)
sked package deploy local -a <alias> -p .

# Production: register first, then deploy
sked package register -p .
sked package deploy registered -a <alias> -p <package-name> --packageVersion <v>
```

After deploy, the updated columns appear on the object's standard list page (e.g. `/p/jobs`).

---

## SPEC.md Structure

```text
# Horizon List Config Progress: <project-name>

## Status
- Phase: [Planning | Implementation | Review | Complete]
- Last Updated: <timestamp>
- Last Agent: <agent-name>

## Configs to Build

- [ ] LC1: <ObjectName> list config — <feature-dir>
- [ ] LC2: <ObjectName> list config — <feature-dir>

## Implementation Notes
- Tenant alias: <alias or "not yet set">

## Completed Configs
- [x] LC1: ...

## Latest Review
(appended by review agent)
```

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Columns not appearing after deploy | `ordering` array doesn't include all column `id` values | Every id in `columns` must appear in `ordering` |
| Column template not rendering | `file` value doesn't match the actual `.njk` filename | Filenames are case-sensitive — verify exact match |
| Nested field is empty | Relationship not fetched | Use GraphQL Schema MCP to confirm the relationship path; check if depth is sufficient |
| `_.host.buildPlatformUrl` returns wrong URL | Wrong slug or query param format | Test the target URL manually first |
| Config not found after deploy | `source` path doesn't match subdirectory name | `source` must be `"./<ObjectName>-DEFAULT_LIST"` exactly |
