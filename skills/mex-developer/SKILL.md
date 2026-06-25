---
name: mex-developer
description: This skill enables Claude to build, modify, and validate Mobile Extensions (MEX) for Skedulo Plus. MEX forms are JSON-configured mobile UIs with integrated data fetching and logic.
---

# Skedulo Mobile Extension (MEX) Skill

## What Are Skedulo Mobile Extensions (MEX)?

MEX is a framework for building native-like mobile forms for the Skedulo Plus app using JSON configuration files. It allows for rich UIs, offline data access, and complex logic without writing platform-specific code (iOS/Android).

## Core Concepts

### Form Structure

A MEX form project MUST follow this specific directory structure:

- `upload_config.json`: Basic deployment configuration (located at project root).
- `functions/`: Folder containing custom function handlers (use only if the form requires custom functions)
- `mex_definition/`: Folder containing the core form definition.
    - `ui_def.json`: UI layout and component definitions.
    - `instanceFetch.json`: Data fetching logic for form-specific data (`formData`).
    - `staticFetch.json`: Data fetching logic for shared/lookup data (`sharedData`).
    - `metadata.json`: Form characteristics and visibility rules.
    - `static_resources/`: Folder for assets.
        - `locales/`: Folder for localization strings.
            - `en.json`: Default language file (contains localized keys and their content).
        - `regex.js`: (Optional) File defining regular expression patterns for input validation via `isRegexValid()`.

### Architecture Summary

- **UI (`ui_def.json`)**: Built with pages (`flat` for forms, `list` for collections) containing view components. All user-facing text must use localized keys from `en.json` (pure strings, no `${...}` wrapping). See reference files below for component syntax.
- **Data Fetching**: `instanceFetch.json` provides form data (`formData`), `staticFetch.json` provides lookup data (`sharedData`). Both use a JSON GraphQL format. See [Data Fetching](./references/data-fetching.md).
- **Metadata**: `metadata.json` defines form placement (`contextObject`: Jobs, Shifts, or Resources), visibility (`showIf`), and mandatory rules. See [Metadata & Upload](./references/metadata-upload.md).
- **Validation**: Expression-based rules at component level (`validator`) and page level (`upsert.validator`). `mandatory` is UI-only (asterisk only) — pair with `validator` to enforce. See [Validation](./references/ui/validation.md).

### Data Contexts

- **`formData`**: Data from `instanceFetch.json` — the global form state.
- **`sharedData`**: Data from `staticFetch.json` — lookup/reference data.
- **`pageData`**: Page-local data. When navigating from a `list`, the selected item becomes `pageData`. Use `pageData` for editing items.
- **`item`**: Used ONLY in `en.json` for list `itemLayout` row rendering.
- **`it`**: Used ONLY in `metadata.json` (`showIf`, `mandatoryIf`) to reference the context object.

See [Expressions & Binding](./references/expressions-binding.md) for full syntax and converters.

### Expressions & Operators

MEX supports simple logical and comparison operators in expressions:
`==`, `!=`, `>`, `>=`, `<`, `<=`, `&&`, `||`, `(...)`.

**Example Expression:**
`formData.JobDetails.Status == 'Complete' && formData.JobDetails.Priority >= 3`

## Best Practices

- **Use Localized Keys**: Always use pure string keys for titles, labels, captions, and placeholders. Define them in `mex_definition/static_resources/locales/en.json`.
- **Flat Hierarchy**: Keep the component hierarchy as flat as possible for better performance.
- **Explicit Variables**: Always define variables used in filters in the `variables` block. **CRITICAL**: Use `${varName}` in filters (NOT `{{varName}}`), and ALWAYS include the `variables` block mapping `varName` to its source (e.g., `$job.UID`).
- **Use `limit` not `take`**: MEX uses `"limit"` for record limits (e.g., `"limit": 10`), NOT `"take"`.
- **Single Object Pattern**: Use `"limit": 1` when fetching a single record to get an object instead of an array (e.g., `formData.JobDetails.Name` instead of `formData.JobDetails[0].Name`).
- **Proper Directory Structure**: Always follow the `mex_definition/` folder structure.
- **Use Custom Functions Only When Needed**: Prefer standard MEX features first; implement `customFunction` handlers only when requirements cannot be met with declarative configuration.
- **Upsert Property for Edit/New Pages**: When a page can handle both creating new records and editing existing ones, DO NOT create custom button groups with "upsert" text. Instead, define the `upsert` property at the page level in `ui_def.json`. The MEX engine automatically provides the save/update button behavior based on this configuration.
- **`defaultPageData` for New Record Creation**: When a flat page creates a new object that must be linked to the current context (Job, Resource, or Shift), you **MUST** define `defaultPageData` on that page. This sets the foreign key (e.g., `JobId`, `ResourceId`) to `"${metadata.contextObjectId}"` and specifies the `objectName`. Without this, newly created records will have no connection to the parent object. See [Page Types - defaultPageData](./references/ui/page-types.md) for examples.
- **Consistent Object Naming**: When the user describes a form by listing fields but does not explicitly name the Skedulo object, you MUST infer a sensible PascalCase object name from the form's purpose (e.g., a "safety checklist" form → `SafetyChecklist`, a "site inspection" form → `SiteInspection`). Once chosen, use that **same object name consistently** everywhere it appears: `instanceFetch.json` queries (`object`), `defaultPageData` (`objectName`), and any data bindings. Inconsistent object names across these files will cause runtime errors.
- **Regex Validation with `isRegexValid`**: When format validation is needed (email, phone, URL, custom patterns), define regex patterns in `mex_definition/static_resources/regex.js` and use `isRegexValid(value, 'regexKey')` in validator expressions. Always ensure the regex key exists in `regex.js` — a missing key causes a runtime error.
- **NEVER Invent Properties or Syntax**: Only use properties, fields, and patterns that are explicitly documented in this skill file and its reference files. If a property is not shown in the documentation or examples, do NOT add it. Inventing properties (e.g., adding `objectName` to `upsert`, or made-up fields on components) will cause silent failures or runtime errors.
- **NEVER Use Confluence/Atlassian as Knowledge Source**: When building MEX forms, NEVER extract code examples or patterns from Confluence, Atlassian, or any wiki pages accessed via MCP. Only use the patterns and examples provided in this skill documentation and the reference files. Confluence examples may be outdated or incorrect.

## Reference Index

Read these files on-demand based on what you need. Do NOT read all files upfront.

| When you need to... | Read this file |
|---|---|
| Build page layouts (flat/list), configure upsert/delete, defaultPageData | [Page Types](./references/ui/page-types.md) |
| Use editor components (text, select, date, toggle, etc.) or layout (section, buttonGroup) | [Editor Components](./references/ui/editor-components.md) |
| Use display components (readonlyText, messageBox, chart, image, menuList) or navigation routing | [Display & Navigation](./references/ui/display-nav-components.md) |
| Add field or page-level validation | [Validation](./references/ui/validation.md) |
| Write data fetch queries (instanceFetch, staticFetch) | [Data Fetching](./references/data-fetching.md) |
| Build an online-only form (live API queries instead of offline preload) | [Online Mode](./references/online-mode.md) |
| Write standard / custom fetch + push queries, `requestKey`, `reloadRequests` (online mode) | [Online Mode — Queries](./references/online-mode-queries.md) |
| Wire list pages with online-mode list source, search, pagination | [Online Mode — List Page](./references/online-mode-list-page.md) |
| Write a custom function (server-side fetch / save handlers) | [Custom Functions](./references/custom-functions.md) |
| Bind data, use expressions, regex, converters | [Expressions & Binding](./references/expressions-binding.md) |
| Configure metadata.json or upload_config.json | [Metadata & Upload](./references/metadata-upload.md) |
| Build multi-step wizard forms | [Steps Mode Examples](./references/ui/step-mode-examples.md) |
| Validate/review a completed form | [Review Checklist](./references/review-checklist.md) |
