# MEX UI Definition and Page Types

MEX UIs are structured into **Page Types** and **View Components**. A MEX form consists of 1 to n pages, but only one page can be rendered on the screen at any given time.

## Root Structure (`ui_def.json`)

The root of the `ui_def.json` file defines the entry point and the collection of pages:

```json
{
  "firstPage": "MyStartPage",
  "pages": {
    "MyStartPage": { "type": "flat", "items": [] },
    "DetailsPage": { "type": "flat", "items": [] },
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
- `items`: An array of **View Components** (used when `mode` is NOT `"steps"`).
- `stepDef`: (Required if `mode` is `"steps"`) Configuration for the multi-step flow.
- `events`: (Optional) Object for page-level lifecycle events.
- `pageDataExpression`: (Optional) Expression to map a specific data object as the page's primary data context.
    - Example: `"pageDataExpression": "formData.JobDetails"`.
    - When set, the page's `pageData` becomes an alias for that object. Editors should then bind to `pageData.FieldName`.
    - Changes made to `pageData` are automatically synchronized back to the source (e.g., `formData.JobDetails`).
- `upsert`: (Optional) Configuration for saving data. **IMPORTANT**: When this property is present, the MEX engine automatically provides an "Add" button for new records and an "Update" button for existing records. DO NOT manually create button groups with "upsert" or "save" text — the engine handles this automatically. Valid sub-properties:
    - `insertTitle`: Localized key. Navigation title when the page is in "Add/Insert" state.
    - `updateTitle`: Localized key. Navigation title when the page is in "Edit/Update" state.
    - `insertButtonText`: Localized key. Save button text for insert state.
    - `updateButtonText`: Localized key. Save button text for update state.
    - `invalidTitle`: Localized key. Title for the validation error popup.
    - `invalidDescription`: Localized key. Description for the validation error popup.
    - `unsavedChangeTitle`: Localized key. Title for the unsaved changes popup.
    - `unsavedChangeDescription`: Localized key. Description for the unsaved changes popup.
    - `validator`: Array of validation rules applied when the user presses the save button. Same format as component-level `validator` (see [Validation](./validation.md)). Use this for **cross-field** or **page-level** validation that individual component validators cannot handle.
    - `readonly`: Expression. When `true`, ALL components on the page become read-only regardless of their individual `readonly` settings.
    - **Do NOT add any other properties** (e.g., `objectName`, `fields`, `objectType`) — they do not exist and will be ignored or cause errors.
- `delete`: (Optional) Configuration for deleting the current record.
    - `canDeleteExpression`: Expression returning a boolean indicating whether to show the delete button.
    - `text`: Localized key. The text of the delete button.
    - `confirm`: Object for the confirmation popup shown when the user taps the delete button.
        - `title`: Localized key. Title of the confirm popup.
        - `description`: Localized key. Description of the confirm popup.
        - `yesBtn`: Localized key. Yes/confirm button text.
        - `noBtn`: Localized key. No/cancel button text.
- `defaultPageData`: (Optional but **CRITICAL when creating new objects**) Provides initial `pageData` for the page when no `pageData` exists yet (i.e., the user is creating a new record, not editing an existing one). **You MUST use this to establish the connection between the new record and the current context object (Job, Shift, or Resource).** Without it, newly created records will be orphaned with no link to their parent.
    - `data`: Object containing default field values. Use `"${metadata.contextObjectId}"` to reference the UID of the current context object (the Job, Shift, or Resource the form is opened from).
    - `objectName`: The Skedulo object type name for the new record.

#### defaultPageData Example
When creating a new custom object (e.g., `SurveyResponse`) from a **Job form** (`contextObject: "Jobs"`):
```json
{
  "type": "flat",
  "title": "NewSurveyTitle",
  "defaultPageData": {
    "data": {
      "JobId": "${metadata.contextObjectId}"
    },
    "objectName": "SurveyResponse"
  },
  "items": [...]
}
```

When creating from a **Global/Resource form** (`contextObject: "Resources"`):
```json
{
  "type": "flat",
  "title": "NewSurveyTitle",
  "defaultPageData": {
    "data": {
      "ResourceId": "${metadata.contextObjectId}"
    },
    "objectName": "SurveyResponse"
  },
  "items": [...]
}
```

At runtime, `pageData` will be initialized as:
```json
{
  "JobId": "actual-job-uid-here",
  "__typename": "SurveyResponse"
}
```

**Key notes:**
- `metadata.contextObjectId` resolves to the UID of the Resource (for Global forms), Job (for Job forms), or Shift (for Shift forms).
- The `objectName` sets the `__typename` on the resulting `pageData`, which the engine uses to determine which Skedulo object to upsert to.
- This is only used when `pageData` is empty (new record creation). If the page receives `pageData` from navigation (e.g., clicking an item in a list), `defaultPageData` is ignored.

#### Example (Standard)
```json
{
  "JobDetailsPage": {
    "type": "flat",
    "title": "DetailsTitle",
    "items": [
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
    "items": [
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

#### Example (with upsert and delete)
```json
{
  "PartEditPage": {
    "type": "flat",
    "title": "EditPartTitle",
    "upsert": {
      "insertTitle": "AddPartTitle",
      "updateTitle": "EditPartTitle",
      "insertButtonText": "AddBtn",
      "updateButtonText": "UpdateBtn"
    },
    "delete": {
      "canDeleteExpression": true,
      "text": "DeletePartBtn",
      "confirm": {
        "title": "ConfirmDeleteTitle",
        "description": "ConfirmDeleteDescription",
        "yesBtn": "ConfirmDeleteYes",
        "noBtn": "ConfirmDeleteNo"
      }
    },
    "items": [
      {
        "type": "textEditor",
        "title": "PartQtyLabel",
        "valueExpression": "pageData.Qty"
      }
    ]
  }
}
```
*(In `en.json`: `"DeletePartBtn": "Delete Part"`, `"ConfirmDeleteTitle": "Delete Part?"`, `"ConfirmDeleteDescription": "Are you sure you want to delete this part?"`, `"ConfirmDeleteYes": "Delete"`, `"ConfirmDeleteNo": "Cancel"`)*

### dataObserver (Page-Level Property)

Observes data changes on the data context and triggers a [custom function](../custom-functions.md) handler.

**Key Properties:**
- `dataExpression`: Array of expressions to observe (e.g., `["pageData.Start", "pageData.End"]`).
- `request`: The action to execute when observed data changes.
    - `type`: `"local"` — runs the handler directly with no API call.
    - `handler`: Custom function expression to execute (e.g., `"cf.handleChange(pageData)"`)

#### Example
```json
{
  "SchedulePage": {
    "type": "flat",
    "title": "ScheduleTitle",
    "dataObserver": [{
      "dataExpression": ["pageData.RegionId"],
      "request": {
        "type": "local",
        "handler": "cf.handleRegionChange(pageData)"
      }
    }],
    "items": []
  }
}
```
Custom function:
```typescript
function handleRegionChange(pageData, { extHelpers }) {
  extHelpers.data.changeData(() => {
    pageData.LocationId = null
  })
}
```

### events (Page-Level Property)

Page-level lifecycle events that inject custom behavior via [custom functions](../custom-functions.md).

**Available Events:**
- `onPreDataLoad`: Triggered when the page loads data. Use it to transform data from the GraphQL structure into a UI-friendly structure. Must return a **new** object (do not mutate and return the original).
- `onPreDataSave`: Triggered when the user saves or navigates back from an edit page. Use it to convert the UI data structure back to the GraphQL-compatible structure. Must return a **new** object.

#### Example
```json
{
  "AvailabilityPage": {
    "type": "flat",
    "title": "AvailabilityTitle",
    "events": {
      "onPreDataLoad": "cf.buildUIStructure(pageData)",
      "onPreDataSave": "cf.buildGraphQLStructure(pageData)"
    },
    "items": []
  }
}
```
Custom functions:
```typescript
// Convert array-based GraphQL data to named-key structure for UI binding
function buildUIStructure(pageData) {
  return {
    Monday: {
      FromTime: pageData.Availability[0].FromTime,
      ToTime: pageData.Availability[0].ToTime
    },
    Tuesday: {
      FromTime: pageData.Availability[1].FromTime,
      ToTime: pageData.Availability[1].ToTime
    }
  }
}

// Convert named-key UI structure back to array for GraphQL
function buildGraphQLStructure(pageData) {
  return [
    { type: "monday", fromTime: pageData.Availability.Monday.FromTime, toTime: pageData.Availability.Monday.ToTime },
    { type: "tuesday", fromTime: pageData.Availability.Tuesday.FromTime, toTime: pageData.Availability.Tuesday.ToTime }
  ]
}
```

### list
Used to render a collection of items from a data source. It uses a single layout template for all items.

**Key Properties:**
- `type`: `"list"`
- `title`: Localized key for the navigation title.
- `header`: (Optional) Configuration for the topmost section of the page.
  - `title`: Localized header title.
  - `description`: Localized header description.
  - `messageBox`: An info box for page-level alerts.
- `sourceExpression`: Expression returning the array of data to display (e.g., `formData.Items`).
- `itemLayout`: **CRITICAL** - This object defines the template for each list item.
    - `type`: Common types include `"titleAndCaption"`.
    - `title`: Expression (via locale) or localized key for the item's primary text.
    - `caption`: Expression (via locale) or localized key for the sub-text.
- `emptyText`: Localized key shown when no data is found.
- `itemClickDestination`: The name of the page to navigate to when an item is tapped (string or RoutingPageDef).
- `addNew`: Configuration for the "Add New" action button
    - `text`: Localized key for the add button text (e.g., `"AddNewProduct"`).
    - `destinationPage`: Page to navigate to when the user taps the add button.
    - `defaultData`: Default data for the new object, passed as `pageData` to the destination page. Must include `data` (object with default field values) and `objectName` (the object type name). A temporary UID is automatically assigned.
    - `showIfExpression`: (Optional) Expression that controls visibility of the add button. If the expression evaluates to false, the add button is hidden.
- `search`: (Optional) Enables client-side search filtering on the list. Properties are nested inside `offlineSearch`.
    - `offlineSearch.placeholder`: Localized key for the search bar placeholder text.
    - `offlineSearch.filterOnProperties`: Array of property paths to filter on (dot notation supported for relationship fields, e.g., `"Resource.Name"`).

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
    "emptyText": "NoPartsFound",
    "addNew": {
      "text": "AddNew",
      "destinationPage": "PartDetailsPage",
      "defaultData": {
        "data": {
          "JobId": "${metadata.contextObjectId}"
        },
        "objectName": "Part"
      }
    },
    "search": {
      "offlineSearch": {
        "placeholder": "SearchPlaceholderKey",
        "filterOnProperties": ["Name"]
      }
    }
  }
}
```
*(In en.json: `"PartNameKey": "${item.Name}", "PartQtyKey": "Quantity: ${item.Quantity}"`)*
