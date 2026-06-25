# Horizon Page Developer

Author and deploy Skedulo Horizon platform pages — deployable artifacts that map a URL slug to a rendered template.

## Use this skill when

- Creating a new Horizon page (slug → template)
- Choosing between Page Builder (`content.json`) and Direct Nunjucks (`content.njk`)
- Authoring `HorizonPage` / `HorizonTemplate` artifacts
- Embedding standard or custom registered components in a page
- Deploying or updating a Horizon page

## Key rules

- Every page is a `HorizonPage` metadata artifact plus a `HorizonTemplate` directory
- Prefer Page Builder (`content.json`) unless Nunjucks is explicitly required
- `kind`: use `PAGE_LAYOUT` for standard typed pages, `PAGE_EXTENDED` for custom or Direct Nunjucks pages
- For built-in object list views, use `horizon-list-config-developer` instead
- For column template syntax, see `page-builder-column-templates`

## Example

```json
{
  "metadata": { "type": "HorizonPage" },
  "slug": "inspections",
  "name": "Inspections",
  "template": "InspectionsTemplate"
}
```
