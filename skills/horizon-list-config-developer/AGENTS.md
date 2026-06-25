# Horizon List Config Developer

Author and deploy Skedulo HorizonListConfig artifacts — the column layout and cell rendering for built-in object list pages (e.g. `/p/jobs`, `/p/resources`).

## Use this skill when

- Configuring columns on a built-in object list page
- Writing or editing a column's Nunjucks `.njk` cell template
- Setting column ordering or the actions panel on a default list
- Deploying or updating a HorizonListConfig

## Key rules

- A config is a `.horizon-list-config.json` metadata file plus a `source` directory with one `.njk` template per column
- `metadata.type` is always `"HorizonListConfig"`
- `ordering` must list every column `id`
- This configures the platform's default list views — for custom pages use `horizon-page-developer`
- For column template syntax, see `page-builder-column-templates`

## Example

```json
{
  "metadata": { "type": "HorizonListConfig" },
  "objectName": "Jobs",
  "name": "Default Jobs",
  "columns": [
    { "id": "Status", "title": "Status", "file": "Status-template.njk" }
  ],
  "ordering": ["Status"],
  "source": "./Jobs-DEFAULT_LIST"
}
```
