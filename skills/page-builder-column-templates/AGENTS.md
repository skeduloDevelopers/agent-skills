# page-builder-column-templates

Reference for Skedulo Page Builder column templates — Nunjucks-based templating for list view columns.

## Use this skill when

- Writing or editing a column template in a Page Builder list view
- Formatting dates, times, or timezones in a column
- Formatting numbers, currency, or percentages in a column
- Rendering a `<brz-lozenge>` or `<brz-link>` component in a column
- Using conditional logic (`{% if %}`) to control column display
- Iterating over multi-select picklist values with `{% for %}`
- Accessing cross-object fields (e.g. `{{ Account.BillingCity }}`)
- Using `$CurrentUser` context in a column template
- Troubleshooting a column template that renders blank, shows raw tags, or displays incorrect values

## What to expect

Once activated, this skill loads the complete column template syntax reference including filters, control flow, Breeze UI components, common patterns, and a troubleshooting guide. It covers the Nunjucks engine constraints (no JavaScript), correct date format strings, currency conventions, and common mistakes.

## Example

```html
{% if JobStatus == "Complete" %}
<brz-lozenge leading-icon="tick" color="positive">{{ JobStatus }}</brz-lozenge>
{% else %}
<brz-lozenge theme="subtle" color="neutral">{{ JobStatus }}</brz-lozenge>
{% endif %}
```
