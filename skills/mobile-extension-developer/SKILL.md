---
name: mobile-extension-developer
description: Build, modify, and validate Skedulo Mobile Extensions (MEX) for the Skedulo Plus mobile app. MEX forms are JSON-configured native mobile UIs with integrated GraphQL data fetching, expressions, localization, and multi-step flows.
displayName: Mobile Extensions
status: available
category: Platform
featured: false
pulseComponents:
  - Mobile Extensions
  - Skedulo Plus
sdks: []
filePatterns:
  - "mex_definition/**/*.json"
  - "upload_config.json"
---

# Skedulo Mobile Extension (MEX) Skill

## What Are Skedulo Mobile Extensions (MEX)?

MEX is a framework for building native-like mobile forms for the Skedulo Plus app using JSON configuration files. It allows for rich UIs, offline data access, and complex logic without writing platform-specific code (iOS/Android).

## Core Concepts

### Form Structure

A MEX form project MUST follow this specific directory structure:

- `upload_config.json`: Basic deployment configuration (located at project root).
- `mex_definition/`: Folder containing the core form definition.
    - `ui_def.json`: UI layout and component definitions.
    - `instanceFetch.json`: Data fetching logic for form-specific data (`formData`).
    - `staticFetch.json`: Data fetching logic for shared/lookup data (`sharedData`).
    - `metadata.json`: Form characteristics and visibility rules.
    - `static_resources/`: Folder for assets.
        - `locales/`: Folder for localization strings.
            - `en.json`: Default language file (contains localized keys and their content).

### UI Definition (`ui_def.json`)

UI is built using a hierarchy of components organized into pages. A MEX form can consist of 1 to n pages. **CRITICAL: All user-facing labels (titles, captions, placeholders, etc.) must use localized keys defined in `locales/en.json`. Use the PURE KEY string (e.g., `"MyLabel"`) instead of wrapping it in `${...}`.**

**Root Structure:**
- `firstPage`: The name of the page to render when the form opens.
- `pages`: A map of page definitions where the key is the page name.

**Page Types:**
Represent the top-level layout structure for a page. Only one page can be rendered at a time.
- `flat`: For standard forms with various view components. Supports **Steps Mode** for multi-step flows (See [Steps Mode Examples](./references/step-mode-examples.md)).
- `list`: For rendering lists of items using a template (`itemLayout`).

**Navigation:**
Navigation between pages is handled by a Routing Engine.
- **Simple Navigation**: A string representing the target page name.
- **Complex Navigation (`RoutingPageDef`)**: Allows for conditional routing and data transfer.
    - `routing`: An array of routing objects with `condition`, `page`, and `transferData`.
    - `transferData`: An object mapping data to be passed to the next page's `pageData`.

**View Components:**
The smallest units of the UI, nested within `flat` page or `section`.
- `Section`: Groups related components.
- `Text Editor`: Single or multi-line text input.
- `Select Editor`: Single-select dropdown/list.
- `Multi Selector Editor`: Multi-select list.
- `Date Time Editor`: Date and/or time picker.
- `Address Editor`: Location/Address selector.
- `Toggle Editor`: Boolean switch.
- `Signature Editor`: Signature capture.
- `Attachments Editor`: Photo and file upload.
- `Read-Only TextView`: Read-only text display.
- `Message Box`: Info/Warning alert boxes.
- `Chart View`: Graphical data visualization.
- `Image View`: Remote image display.
- `Button Group`: Action buttons.

### Data Fetching

MEX uses a specialized JSON format to define GraphQL-like data requirements.

**`instanceFetch.json` and `staticFetch.json` Structure:**

```json
{
  "type": "GraphQl",
  "QueryResultKey": {
    "object": "ObjectName",
    "fields": [
      "Field1",
      "Field2",
      "Relationship.Field3"
    ],
    "filter": "Field1 == '${varName}'",
    "variables": {
      "varName": "$job.UID"
    }
  }
}
```

- `type`: Must be `"GraphQl"`.
- `QueryResultKey`: The key under which data will be available in the data context (`formData` or `sharedData`).
- `object`: The Skedulo object to query.
- `fields`: Array of fields to retrieve. Supports dot notation for relationships.
- `filter`: Filter string using variables.
- `variables`: Mapping of filter variables to context values (e.g., `$job.UID`, `$resource.UID`).

### Data Context & Binding

Data is accessed in `ui_def.json` and `en.json` using specialized contexts:

- **`formData`**: Accesses data fetched via `instanceFetch.json`. This is the global form state.
- **`sharedData`**: Accesses data fetched via `staticFetch.json`. Used for lookup data.
- **`pageData`**: Accesses data local to the current page. When navigating from a `list` to a `flat` page, the selected item is automatically passed as `pageData`. **Use `pageData` for editing items navigated to from a list.**
- **`item`**: Used ONLY in `en.json` to refer to an individual row item in a `list` page's `itemLayout`.
- **`it`**: Used ONLY in `metadata.json` (`showIf`, `mandatoryIf`) to refer to the form's context object (e.g., the Job).

**Data Flow Example**:
1. A `list` page uses `sourceExpression: "formData.JobProducts"`.
2. The `itemLayout` references a key in `en.json` that uses `${item.Name}`.
3. When a row is clicked, `itemClickDestination` navigates to an "Edit" page.
4. On the "Edit" page, `valueExpression` for an editor should be `"pageData.Name"`. Mutations here are automatically saved back to the original `formData.JobProducts` array.

### Localization (`static_resources/locales/en.json`)

Localized keys are used throughout the UI. The JSON file maps keys to actual content:
```json
{
  "FormTitle": "My Awesome Form",
  "SubmitButton": "Submit Data",
  "SuccessMessage": "Successfully saved!"
}
```
In `ui_def.json`, these are referenced using the pure key name, e.g., `"title": "FormTitle"`.

**IMPORTANT**: The locale content *itself* can contain expressions, e.g., `"FieldLabel": "${formData.JobDetails.Name}"`.

### Metadata (`metadata.json`)

Defines how the form behaves in the mobile app.

- `summary`: Description shown in the app (Localized Key).
- `contextObject`: The object the form is attached to (`Jobs`, `Resources`, etc.).
- `showIf`: Expression determining if the form is visible.
- `mandatoryIf`: Expression determining if the form is mandatory.

### Expressions & Operators

MEX supports simple logical and comparison operators in expressions:
`==`, `!=`, `>`, `>=`, `<`, `<=`, `&&`, `||`, `(...)`.

**Example Expression:**
`formData.JobDetails.Status == 'Complete' && formData.JobDetails.Priority >= 3`

## Best Practices

- **Use Localized Keys**: Always use pure string keys for titles, labels, captions, and placeholders. Define them in `mex_definition/static_resources/locales/en.json`.
- **Flat Hierarchy**: Keep the component hierarchy as flat as possible for better performance.
- **Explicit Variables**: Always define variables used in filters in the `variables` block.
- **Proper Directory Structure**: Always follow the `mex_definition/` folder structure.
- **Skip Custom Functions**: For the current scope, focus on standard MEX features and avoid `customFunction`.

## References

For detailed information on components and data fetching, refer to the following:
- [UI Components](./references/ui-components.md)
- [Steps Mode Examples](./references/step-mode-examples.md)
- [Data Fetching](./references/data-fetching.md)
- [Metadata & Upload](./references/metadata-upload.md)
- [Expressions & Binding](./references/expressions-binding.md)
