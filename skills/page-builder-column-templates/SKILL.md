---
name: page-builder-column-templates
description: "Use when working with Skedulo Page Builder list view column templates — Nunjucks syntax, brz-link, brz-lozenge, date/timezone formatting, number/currency, picklists, conditional display, cross-object fields, and $CurrentUser context."
displayName: Page Builder Column Templates
status: available
category: Platform
featured: false
pulseComponents:
  - List Views
  - Column Templates
sdks: []
filePatterns: []
---

# Page Builder Column Templates Skill

Provides the canonical reference for Skedulo's advanced column configuration in list views. Column templates use a Nunjucks-based templating engine with HTML support. JavaScript is not supported in column templates.

## Reference

Load the full column template reference before writing or reviewing:

- `column-template-reference.md` — complete syntax guide covering cross-object fields, styling, hyperlinks, conditionals, expressions, math, comparisons, logic, number/currency/percentage formatting, date/time formatting, timezone manipulation, multi-select picklist rendering, lozenges, and current-user context

> **Note:** Image paths in the reference (e.g. `/images/customization/...`) are for the published docs site and are not renderable in this context. Omit or replace them as appropriate for the output format.

---

## Template engine overview

Column templates are evaluated by a Nunjucks-based engine at render time. They support:

- **Variable interpolation** — `{{ FieldName }}`
- **Cross-object traversal** — `{{ Account.BillingCity }}`
- **Filters** — piped functions like `date()`, `number()`, `truncate()`
- **Control flow** — `{% if %}`, `{% elseif %}`, `{% else %}`, `{% endif %}`
- **Loops** — `{% for item in field %}` for multi-select picklists
- **Set** — `{% set varName = expression %}` for intermediate values
- **Comments** — `{# comment text #}`
- **Breeze UI web components** — `<brz-link>` and `<brz-lozenge>`

Templates produce HTML. Standard HTML tags (`<b>`, `<i>`, `<u>`, `<span>`, `<ul>`, `<li>`) are supported for styling.

---

## Quick reference: template syntax

### Field output

```html
{{ FieldName }}
{{ RelatedObject.FieldName }}
```

### Conditionals

```html
{% if FieldName %} ... {% else %} ... {% endif %}
{% if Type == "Repair" %} ... {% elseif Type == "Installation" %} ... {% else %} ... {% endif %}
```

### Loops (multi-select picklists)

```html
{% for item in fieldname %} {{ item }} {% endfor %}
```

### Filters

| Filter | Example |
|--------|---------|
| Date formatting | `{{ CreatedDate \| date("ddd D MMM YYYY") }}` |
| Timezone override | `{{ Start \| date("tz", Region.Timezone) }}` |
| Number decimals | `{{ Total \| number(decimals=2) }}` |
| Truncate | `{{ category \| string \| truncate(50, "...") }}` |

### Breeze UI components

| Component | Usage |
|-----------|-------|
| `brz-link` | Hyperlinks with `href`, `target`, `rel`, `link-type` attributes |
| `brz-lozenge` | Status lozenges with `size`, `theme`, `color`, `leading-icon` properties |

### Current user

Access logged-in user data via `$CurrentUser`:

```html
{{ $CurrentUser.Resources[0].PrimaryRegion.Name }}
{{ $CurrentUser.Category }}
{{ $CurrentUser.UserTypes }}
```

---

## Writing guidance

When writing or reviewing documentation about column templates:

### Voice and structure

- Use **imperative mood** for steps: "Enter the following in the Column template field" — not "You should enter."
- Show the template code first, then explain what it does. Readers scan for code blocks.
- Every code example must use ` ```html ` fenced blocks — column templates are HTML with Nunjucks tags.
- Keep examples minimal. Show one concept per block. Combine concepts only when demonstrating a real-world pattern (e.g., conditional lozenge with icon).

### Field name conventions

- Use `{{ FieldName }}` with PascalCase in generic examples (matching Skedulo's schema convention).
- Use the actual field name when writing for a specific object (e.g., `{{ Duration }}`, `{{ Start }}`).
- Custom fields use their API name exactly as configured — remind readers to check **Settings > Objects & fields** for the correct name.

### Common mistakes to watch for

| Mistake | Correct form | Notes |
|---------|-------------|-------|
| `{& else &}` | `{% else %}` | Nunjucks uses `{% %}` for all control tags |
| `{{ % if ... % }}` | `{% if ... %}` | Double-brace `{{ }}` is for output only, not control flow |
| Missing `{% endif %}` | Always close conditionals | Unclosed tags produce render errors |
| `{{ field \| date("format") }}` on a non-date field | Only apply `date()` to date/datetime fields | Produces garbled output on strings or numbers |
| Hardcoded tenant URL | Use relative paths or `buildPlatformUrl()` | Breaks when config moves between tenants |
| JavaScript in templates | Not supported | Only Nunjucks + HTML |

### Date formatting pitfalls

- Raw date fields display as UTC strings (e.g., `2021-02-19T16:00:00.000Z`). Always apply a `date()` filter.
- The `date()` filter auto-converts to the user's device timezone. To override, use `date("tz", Region.Timezone)` first, then format: `{{ tzStart \| date("h:mma") }}`.
- `M` vs `m`: uppercase `M` = month, lowercase `m` = minute. This is the most common date formatting error.

### Number and currency

- `number(decimals=N)` rounds to the specified decimal places. `3` with `decimals=2` renders as `3.00`, and `3.456` renders as `3.46`.
- Currency symbols go outside the expression: `${{ Cost \| number(decimals=2) }}`, not inside the filter.
- Calculated values (e.g., `{{ Duration * Rate }}`) are display-only — users cannot filter or sort on them.

---

## Common patterns

### Status lozenge with conditional icon

```html
{% if JobStatus == "Complete" %}
<brz-lozenge leading-icon="tick" color="positive">{{ JobStatus }}</brz-lozenge>
{% elseif JobStatus == "In Progress" %}
<brz-lozenge leading-icon="in-progress" color="info">{{ JobStatus }}</brz-lozenge>
{% elseif JobStatus == "Cancelled" %}
<brz-lozenge leading-icon="warning" color="negative">{{ JobStatus }}</brz-lozenge>
{% else %}
<brz-lozenge theme="subtle" color="neutral">{{ JobStatus }}</brz-lozenge>
{% endif %}
```

### Hyperlinked name with bold formatting

```html
<brz-link href="/job/{{ UID }}"><b>{{ Name }}</b> - ({{ Type }})</brz-link>
```

### Region-aware date/time range

```html
{% if Start %}
{% set tzStart = Start | date("tz", Region.Timezone) %}
{% set tzEnd = End | date("tz", Region.Timezone) %}
{{ tzStart | date("ddd D MMM YYYY") }}, </br>
{{ tzStart | date("h:mma") }} - {{ tzEnd | date("h:mma (z)") }}
{% else %}
<span style="color: #7d879c;">Not Set</span>
{% endif %}
```

### Currency with threshold highlight

```html
{% if TotalCost > 1000 %}
<b style="color: #d32f2f;">${{ TotalCost | number(decimals=2) }}</b>
{% else %}
${{ TotalCost | number(decimals=2) }}
{% endif %}
```

### Multi-select picklist as lozenges

```html
{% for item in category %}<brz-lozenge style="margin: var(--sp-spacing-1)" theme="subtle" color="neutral">{{ item }}</brz-lozenge>{% endfor %}
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Column shows raw `{{ FieldName }}` text | Field name doesn't match schema | Verify field API name in Settings > Objects & fields |
| Column is blank | Field is null/empty and no fallback | Add `{% if FieldName %}...{% else %}Not set{% endif %}` |
| Date shows as UTC string | Missing `date()` filter | Apply `{{ Field \| date("ddd D MMM YYYY") }}` |
| Date shows wrong timezone | Displaying in user's local tz, not job's | Use `date("tz", Region.Timezone)` before formatting |
| Lozenge doesn't render | Typo in component name or missing closing tag | Must be `<brz-lozenge>...</brz-lozenge>` (not self-closing) |
| Cross-object field is blank | Relationship not configured or field name wrong | Check the lookup exists on the object and prefix correctly: `{{ Account.BillingCity }}` |
| `buildPlatformUrl` returns nothing | Wrong argument format | Must be a page slug string: `buildPlatformUrl('page-slug?param=value')` |

---

## Verification checklist

Before publishing column template documentation:

- [ ] Every code example renders valid HTML + Nunjucks (no `{& &}` or `{{ % %}}` syntax)
- [ ] Field names match Skedulo schema conventions (PascalCase for standard, exact API name for custom)
- [ ] Date format strings use correct case (`M` for month, `m` for minute)
- [ ] No hardcoded tenant URLs — relative paths or `buildPlatformUrl()` only
- [ ] Currency/percentage symbols are outside template expressions
- [ ] Conditional examples include `{% endif %}` closing tags
- [ ] Cross-object examples specify the relationship prefix
- [ ] `$CurrentUser` examples note that available fields depend on tenant configuration
