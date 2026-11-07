# Page Builder Full-Page Patterns

Complete `content.json` examples for the three coordinated Page Builder page types. Component
properties, `resourceName` casing, and `relationshipResolution` rules are in the main
[SKILL.md](../SKILL.md); artifact schemas (HorizonPage / HorizonTemplate) are in the
`horizon-page-developer` skill.

## Naming for a coordinated page set

| Item | Pattern | Example |
|---|---|---|
| Page file | `page-builder-<resource>.horizon-page.json` | `page-builder-shift-types.horizon-page.json` |
| Page slug | `page-builder-<resource>` | `page-builder-shift-types` |
| Template directory | `page-builder-<resource>-template/` | `page-builder-shift-types-template/` |
| Template name | `page-builder-<resource>-template` | `page-builder-shift-types-template` |
| Content file | always `content.json` | — |
| JSON `id` | must match the page slug | `page-builder-shift-types` |

When you create a detail page, also create the list and create pages, and test all three routes.

## Pattern A: Detail page (`object_record` + `tabs`)

```json
{
  "id": "page-builder-shift-types",
  "template": "tabs",
  "type": "object_record",
  "resourceName": "Shift Types",
  "enableOverride": true,
  "sections": {
    "header": {
      "packageName": "page-builder",
      "component": "PageHeader",
      "properties": {
        "title": "{{ Name if Name != null else UID }}",
        "subtitle": "<platform-component package-name=\"page-builder\" name=\"LinkButton\" label='Back' type='transparent-primary' path='/p/shift-types' leadingIcon='chevronLeft' />"
      }
    },
    "tabs": [
      {
        "name": "Details",
        "packageName": "page-builder",
        "component": "FieldLayout",
        "route": "details",
        "properties": {
          "displayMode": "organizeManually",
          "fields": [
            {
              "name": "Name",
              "label": "Name",
              "type": "string",
              "required": true,
              "disabled": false,
              "placeholder": "Enter name"
            }
          ]
        }
      },
      {
        "name": "History",
        "route": "history",
        "packageName": "page-builder",
        "component": "RelatedList",
        "properties": {
          "resourceName": "History",
          "query": "entityId:{{ UID }}",
          "columns": ["CreatedDate", "CreatedBy", "Changes"],
          "hideSavedViews": true,
          "sorting": ["-CreatedDate"]
        }
      }
    ]
  }
}
```

Detail pages receive `record` and `recordContext` props automatically; tab routes become
`/p/<slug>/<route>` URLs.

## Pattern B: List page (`list` + `header-body`)

```json
{
  "id": "page-builder-shift-types-list",
  "template": "header-body",
  "type": "list",
  "resourceName": "Shift Types",
  "enableOverride": true,
  "sections": {
    "header": {
      "packageName": "page-builder",
      "component": "PageHeader",
      "properties": {
        "title": "Shift Types",
        "actions": [
          {
            "name": "Create button",
            "packageName": "page-builder",
            "component": "LinkButton",
            "properties": {
              "label": "Create new",
              "type": "primary",
              "path": "create"
            }
          }
        ]
      }
    },
    "tabs": [
      {
        "name": "List",
        "packageName": "listview",
        "component": "ListView",
        "route": "list",
        "properties": {
          "resourceName": "Shift Types",
          "listConfig": {
            "columns": {
              "PageBuilder-Item": {
                "title": "Name",
                "template": "<brz-link href=\"/p/shift-types/{{_.record.primaryKeyValue}}\">{{Name or UID}}</brz-link>"
              }
            },
            "ordering": ["PageBuilder-Item"],
            "depth": 1,
            "relationshipResolution": { "allow": ["CreatedBy", "CreatedBy.userAvatar"] },
            "displayedActions": { "showActions": false, "displayedActions": [] }
          },
          "columns": ["PageBuilder-Item"],
          "sorting": ["-CreatedDate"]
        }
      }
    ]
  }
}
```

The inline `listConfig` here pins per-page columns; omit it to inherit the object's default
`HorizonListConfig` — see the SKILL.md **ListView Component** section for the tradeoffs and the
whitelist rules behind `relationshipResolution`.

## Pattern C: Create page (`create` + `header-body`)

```json
{
  "id": "page-builder-shift-types-create",
  "template": "header-body",
  "type": "create",
  "resourceName": "Shift Types",
  "enableOverride": true,
  "sections": {
    "header": {
      "packageName": "page-builder",
      "component": "PageHeader",
      "properties": {
        "title": "Create shift type",
        "actions": []
      }
    },
    "tabs": [
      {
        "name": "Create",
        "packageName": "page-builder",
        "component": "CreateFieldLayout",
        "route": "create",
        "properties": {
          "resourceName": "Shift Types",
          "displayMode": "organizeManually",
          "fields": [
            {
              "name": "Name",
              "label": "Name",
              "type": "string",
              "required": true,
              "disabled": false,
              "placeholder": "Enter name"
            }
          ]
        }
      }
    ]
  }
}
```

Uses `CreateFieldLayout` (not `FieldLayout`) — no record context exists on a create page.

## Multi-column layout recipe

Nest Containers and set `display.columns` on the children (12-column grid):

```json
{
  "packageName": "page-builder",
  "component": "Container",
  "properties": {
    "displayDirection": "row",
    "gap": 16,
    "padding": 16,
    "backgroundColor": "gray",
    "children": [
      {
        "packageName": "page-builder",
        "component": "Container",
        "properties": { "displayDirection": "column", "align": "start" },
        "display": { "columns": 6, "mode": "Card", "padding": 16 }
      },
      {
        "packageName": "page-builder",
        "component": "Container",
        "properties": { "displayDirection": "column", "align": "start" },
        "display": { "columns": 6, "mode": "Card", "padding": 16 }
      }
    ]
  }
}
```

Three equal columns: `"columns": 4` on each child.

## Rich headers

Embed icons and links via `<platform-component>` tags in a subtitle or a Code component:

```json
{
  "packageName": "page-builder",
  "component": "PageHeader",
  "properties": {
    "title": "{{ Name }}",
    "subtitle": "<div class='tw-flex tw-items-center tw-gap-2'><platform-component package-name='icons' name='Icon' icon='briefcase' size='18'></platform-component><span>{{ JobStatus }}</span></div>"
  }
}
```

## Best practices

1. Set `enableOverride: true` so admins can customize without touching the base template
2. Keep page types coordinated — detail, list, and create pages together
3. Populate titles/subtitles with Nunjucks field values for context
4. Use sensible default sorting (e.g. `["-CreatedDate"]`)
5. Follow the naming table above exactly — inconsistent names are the top deploy failure
