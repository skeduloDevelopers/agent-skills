# Horizon Page Developer

Author and deploy Skedulo Horizon platform pages — deployable artifacts that map a URL slug to a
rendered template.

## Use this skill when

- Creating a new Horizon page (slug → template)
- Choosing between Page Builder, Custom Page Builder, and Direct Nunjucks
- Authoring `HorizonPage` / `HorizonTemplate` artifacts
- Embedding standard or custom registered components in a page
- Deploying or updating a Horizon page

## Key rules

- Every page is a `HorizonPage` metadata artifact plus a `HorizonTemplate` directory
- `HorizonPage` requires `name`, `templateName`, `slug`, `published`, and `pageType`; there is no
  `template` field, and the `label`/`path`/`componentBundleName` shape is deprecated and will not
  deploy
- `templateName` must exactly match the `HorizonTemplate`'s `name` — a mismatch deploys but the
  page renders nothing
- Prefer Page Builder (`content.json`) unless Nunjucks is explicitly required
- `kind`: `PAGE_LAYOUT` for standard typed pages, `PAGE_EXTENDED` for custom or Direct Nunjucks
- For built-in object list views, use `horizon-list-config-developer` instead
- For `content.json` schema and components, see the `page-builder` skill
- For column template syntax, see `page-builder-column-templates`

## Example

```json
{
  "metadata": { "type": "HorizonPage" },
  "name": "Inspections",
  "templateName": "inspections-template",
  "slug": "inspections",
  "published": true,
  "pageType": "PAGE_BUILDER"
}
```
