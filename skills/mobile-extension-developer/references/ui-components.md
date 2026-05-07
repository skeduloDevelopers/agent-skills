# MEX UI Definition and Page Types

MEX UIs are structured into **Page Types** and **View Components**. A MEX form consists of 1 to n pages, but only one page can be rendered on the screen at any given time.

## Root Structure (`ui_def.json`)

The root of the `ui_def.json` file defines the entry point and the collection of pages:

```json
{
  "firstPage": "MyStartPage",
  "pages": {
    "MyStartPage": { "type": "flat", "children": [] },
    "DetailsPage": { "type": "flat", "children": [] },
    "ListPage": { "type": "list", "itemLayout": { "type": "titleAndCaption" } }
  }
}
```

- `firstPage`: String name of the initial page.
- `pages`: Object map where keys are page names and values are Page Type definitions.

**IMPORTANT: Localization**
All fields that take a `title`, `caption`, `placeholder`, `text`, `emptyText`, `stepItemText`, or `errorMessage` MUST use localized string keys (e.g., `"MyLabelKey"`). The actual content is stored in `mex_definition/static_resources/locales/en.json`. **Do not wrap keys in `${...}` in `ui_def.json`.**

## Page Types

Instead of generic components, think of these as top-level screen configurations.

### flat
The standard page type for data entry, details, and general forms. It renders a collection of view components in a vertical layout. It can also operate in **Steps Mode** to split a form into multiple sequential or conditional screens. (See [Steps Mode Examples](./step-mode-examples.md))

**Key Properties:**
- `type`: `"flat"`
- `mode`: (Optional) Set to `"steps"` to enable step-by-step navigation.
- `title`: Localized key for the page title.
- `header`: (Optional) Configuration for the topmost section of the page.
    - `title`: Localized header title.
    - `description`: Localized header description.
    - `messageBox`: An info box for page-level alerts.
- `children`: An array of **View Components** (used when `mode` is NOT `"steps"`).
- `stepDef`: (Required if `mode` is `"steps"`) Configuration for the multi-step flow.
- `events`: (Optional) Object for page-level lifecycle events.
- `pageDataExpression`: (Optional) Expression to transform or filter data.
- `upsert`: (Optional) Configuration for saving data.

#### Example (Standard)
```json
{
  "JobDetailsPage": {
    "type": "flat",
    "title": "DetailsTitle",
    "children": [
      {
        "type": "textEditor",
        "title": "JobNameLabel",
        "valueExpression": "formData.Job.Name"
      }
    ]
  },
  "PartEditPage": {
    "type": "flat",
    "title": "EditPartTitle",
    "children": [
      {
        "type": "textEditor",
        "title": "PartQtyLabel",
        "valueExpression": "pageData.Qty"
      }
    ]
  }
}
```
*(Note: `PartEditPage` is navigating from `PartsListPage`. `pageData.Qty` binds to the `Qty` field of the selected part. Changes are automatically mapped back to `formData.JobParts`.)*

### list
Used to render a collection of items from a data source. It uses a single layout template for all items.

**Key Properties:**
- `type`: `"list"`
- `title`: Localized key for the navigation title.
- `sourceExpression`: Expression returning the array of data to display (e.g., `formData.Items`).
- `itemLayout`: **CRITICAL** - This object defines the template for each list item.
    - `type`: Common types include `"titleAndCaption"`.
    - `title`: Expression (via locale) or localized key for the item's primary text.
    - `caption`: Expression (via locale) or localized key for the sub-text.
- `emptyText`: Localized key shown when no data is found.
- `itemClickDestination`: The name of the page to navigate to when an item is tapped (string or RoutingPageDef).
- `addNew`: Configuration for the "Add New" action button.

#### Example
```json
{
  "PartsListPage": {
    "type": "list",
    "title": "PartsListTitle",
    "sourceExpression": "formData.JobParts",
    "itemLayout": {
      "type": "titleAndCaption",
      "title": "PartNameKey",
      "caption": "PartQtyKey"
    },
    "itemClickDestination": "PartDetailsPage",
    "emptyText": "NoPartsFound"
  }
}
```
*(In en.json: `"PartNameKey": "${item.Name}", "PartQtyKey": "Quantity: ${item.Quantity}"`)*

---

## View Components (Layout & Structure)

### Section
Groups multiple related components together.

**Key Properties:**
- `type`: `"section"`
- `title`: Localized section header title key.
- `items`: Array of View Components.

#### Example
```json
{
  "type": "section",
  "title": "ContactSection",
  "items": [
    {
      "type": "textEditor",
      "title": "PhoneLabel",
      "valueExpression": "formData.Contact.Phone"
    }
  ]
}
```

### Button Group
Renders a group of action buttons.

**Key Properties:**
- `type`: `"buttonGroup"`
- `layout`: `"horizontal"` or `"vertical"`.
- `items`: Array of button definition objects.

#### Example
```json
{
  "type": "buttonGroup",
  "layout": "horizontal",
  "items": [
    {
      "text": "SubmitBtn",
      "theme": "primary",
      "behavior": {
        "type": "custom",
        "functionExpression": "cf.submitForm()"
      }
    }
  ]
}
```

---

## Editor Components (Inputs)

### Text Editor
Single or multi-line text input.
- `type`: `"textEditor"`
- `title`: Localized label key.
- `valueExpression`: Data binding.
- `readonly`: (Optional) Expression to disable editing.

#### Example
```json
{
  "type": "textEditor",
  "title": "DescriptionTitle",
  "valueExpression": "formData.Job.Description",
  "multiLine": true,
  "placeholder": "EnterDescription"
}
```

### Select Editor
Single-select dropdown or list.
- `type`: `"selectEditor"`
- `title`: Localized label key.
- `sourceExpression`: Data context path (e.g., `sharedData.Options`).
- `displayExpression`: Property of the option to display.
- `valueExpression`: Binding for the selected UID.

#### Example
```json
{
  "type": "selectEditor",
  "title": "StatusTitle",
  "sourceExpression": "sharedData.Statuses",
  "displayExpression": "Name",
  "valueExpression": "formData.Job.Status"
}
```

### Multi Selector Editor
Multi-select list.
- `type`: `"multiSelectorEditor"`

#### Example
```json
{
  "type": "multiSelectorEditor",
  "title": "PartsTitle",
  "sourceExpression": "sharedData.Parts",
  "displayExpression": "Name",
  "valueExpression": "formData.SelectedParts"
}
```

### Date Time Editor
- `type`: `"dateTimeEditor"`
- `mode`: `"date"`, `"time"`, or `"datetime"`.

#### Example
```json
{
  "type": "dateTimeEditor",
  "title": "ScheduledDate",
  "mode": "datetime",
  "valueExpression": "formData.Job.Start"
}
```

### Address Editor
- `type`: `"addressEditor"`
- `structureExpression`: Binding for the entire address object.

#### Example
```json
{
  "type": "addressEditor",
  "title": "LocationTitle",
  "structureExpression": "formData.Job.Address",
  "displayExpression": "FullAddress"
}
```

### Toggle Editor
Boolean switch.
- `type`: `"toggleEditor"`

#### Example
```json
{
  "type": "toggleEditor",
  "title": "UrgentTitle",
  "valueExpression": "formData.Job.Urgent"
}
```

### Signature Editor
Signature capture.
- `type`: `"signatureEditor"`

#### Example
```json
{
  "type": "signatureEditor",
  "title": "CustomerSignature",
  "valueExpression": "formData.Job.Signature"
}
```

### Attachments Editor
Photo and file upload.
- `type`: `"attachmentsEditor"`

#### Example
```json
{
  "type": "attachmentsEditor",
  "title": "PhotosTitle",
  "valueExpression": "formData.Job.Photos"
}
```

---

## Read-Only & Display Components

### Read-Only TextView
Displays data.
- `type`: `"readonlyTextView"`
- `text`: Localized key (can contain expressions).

#### Example
```json
{
  "type": "readonlyTextView",
  "title": "SummaryTitle",
  "text": "JobSummaryContent"
}
```
*(In en.json: `"JobSummaryContent": "Job ${formData.Job.Name} is currently ${formData.Job.Status}"`)*

### Message Box
Themed alerts.
- `type`: `"messageBox"`
- `theme`: `"success"`, `"primary"`, `"danger"`, or `"warning"`.

#### Example
```json
{
  "type": "messageBox",
  "theme": "warning",
  "title": "WarningTitle",
  "text": "IncompleteDataMsg"
}
```

### Chart View
- `type`: `"chartView"`
- `chartType`: `"pie"`, `"bar"`, `"line"`, or `"multi-lines"`.

#### Example
```json
{
  "type": "chartView",
  "chartType": "bar",
  "title": "PerformanceChart",
  "dataExpression": "sharedData.Stats",
  "stepItemText": "StepLabelKey"
}
```

### Image View
- `type`: `"imageView"`

#### Example
```json
{
  "type": "imageView",
  "title": "PhotoTitle",
  "image": {
    "imageUrl": "https://example.com/image.jpg"
  }
}
```

### Menu List
Renders a list of navigation options.
- `type`: `"menuList"`
- `items`: Array of objects:
    - `title`: Localized title key.
    - `itemClickDestination`: String or RoutingPageDef.

#### Example
```json
{
  "type": "menuList",
  "items": [
    {
      "title": "DetailsMenuTitle",
      "itemClickDestination": "DetailsPage"
    }
  ]
}
```

---

## Navigation & Routing

Navigation defines how users move between pages. Properties like `itemClickDestination` and `destinationPage` use a **RoutingType**.

### RoutingType
Can be a simple **string** or a **RoutingPageDef** object.

- **String**: The name of the target page (e.g., `"DetailsPage"`).
- **RoutingPageDef**: Complex routing with logic.
    - `routing`: Array of routing rules.
        - `page`: Target page name.
        - `condition`: (Optional) Expression to evaluate. The first rule with a `true` condition (or no condition) is followed.
        - `transferData`: (Optional) Object mapping data to the next page's `pageData`. Supports one level of expression evaluation (e.g., `{"Id": "${it.UID}"}`).

### Components using Navigation
- **list**: `itemClickDestination` (string or RoutingPageDef).
- **list > addNew**: `destinationPage` (string or RoutingPageDef).
- **menuList** (View Component): `itemClickDestination` (string or RoutingPageDef).

---

## Common Component Attributes

Applicable to almost all View Components:
- `showIfExpression`: Expression to toggle visibility.
- `readonly`: Expression to toggle read-only state (primarily for editors).
- `title`: Localized string key for the component's label/header (Pure string, no `${}`).
- `caption`: Localized string key for the component's sub-text/description (Pure string, no `${}`).
- `mandatory`: Boolean or expression to show a required asterisk (*).
- `validator`: Object for custom validation logic.
    - `type`: `"expression"`
    - `expression`: Logic that must return `true` for validity.
    - `errorMessage`: Localized key shown if validation fails.
