# MEX Expressions & Binding Reference

Expressions allow you to access dynamic data, perform calculations, and control UI behavior.

## Symbols and Usage

- **Localized Strings**: Used in `title`, `text`, `caption`, `placeholder`, `body`, etc. 
    - Format: `"key"`. (e.g., `"MyTitle"`)
    - These refer to keys in `mex_definition/static_resources/locales/en.json`.
    - **CRITICAL**: These fields contain the PURE KEY string, not a `${key}` expression.
    - The value IN the locale file can contain dynamic expressions like `"${formData.Field}"`.
- **Data Expressions**: Used in properties ending in `Expression` (e.g., `valueExpression`, `sourceExpression`, `showIfExpression`). 
    - These are raw strings without `${}` unless they are part of a larger localized string or being used inside one. (e.g., `sharedData.TypeList`)
- **Data Transfer**: Used in `transferData` objects within navigation.
    - Format: `{"Key": "${expression}"}` .
    - Similar to `en.json`, expressions here are wrapped in `${...}` to be evaluated before being passed to the next page as `pageData`.

## Supported Operators

MEX supports a limited set of operators. **Do not use unsupported operators or deeply nested groupings.**

- **Comparison**: `==` (Equals), `!=` (Not Equals), `>` (Greater), `>=` (Greater/Equals), `<` (Less), `<=` (Less/Equals)
- **Logical**: `&&` (AND), `||` (OR), `!` (NOT)
- **Grouping**: `(...)` (Maximum 1 nested level recommended)

## Data Binding Contexts

### `formData`
Accessed via `formData.QueryResultKey.FieldName`.
- `QueryResultKey` is the key defined in `instanceFetch.json`.
- Used for form-specific data saved back to Skedulo.

### `sharedData`
Accessed via `sharedData.QueryResultKey.FieldName`.
- `QueryResultKey` is the key defined in `staticFetch.json`.
- Used for read-only/lookup data shared across forms.

### `it`
- Used in `metadata.json` (`showIf`, `mandatoryIf`, `mandatoryExpression`) to refer to the context object (e.g., Job).
- Example: `it.Status == 'In Progress'`

### `item`
- Used ONLY in `en.json` to refer to the current item being rendered in a `list` page's `itemLayout` or a `selectEditor` selection page.
- **For Object lists**: Use `${item.FieldName}`.
- **For Picklists/Vocabulary** (`sharedData.__vocabulary.X`): entries are `{ Label, Value }` objects, so use `${item.Label}`.
- Example in `en.json`: `"ItemName": "${item.Name}"`

### `pageData`
- Used to access data local to the current page.
- **Navigation Flow**: When navigating from a `list` to a `flat` page (via `itemClickDestination`), the selected item's data is automatically passed to the next page as `pageData`.
- **`pageDataExpression`**: In a `flat` page, you can define `"pageDataExpression": "formData.SomeObject"`. This makes `pageData` refer to `formData.SomeObject` for that page.
- **Edit Binding**: On the destination page, use `pageData.FieldName` for data binding. Mutations on `pageData` are automatically synchronized with the source (either the list item or the object mapped via `pageDataExpression`).
- **CRITICAL**: Do NOT use `formData.Array[index]` for editing list items or nested objects. Always use `pageData`.

## Built-in Converters

### `converters.ui.translatePicklist(value, vocabularyList)`
Translates a picklist stored value to its display label. Use this in `displayExpression` for `selectEditor` components that use vocabulary/picklist data sources.

- **`value`**: The data expression pointing to the stored picklist value (e.g., `pageData.PlantType`).
- **`vocabularyList`**: The vocabulary source expression (e.g., `sharedData.__vocabulary.PlantTypeVocab`).

**Why**: On Platform orgs, the stored picklist value (e.g., `AwaitingForOrders`) can differ from its display label (`Awaiting For Orders`). This converter resolves the correct label.

**Example** in `ui_def.json`:
```json
{
  "type": "selectEditor",
  "title": "PlantTypeTitle",
  "sourceExpression": "sharedData.__vocabulary.PlantTypeVocab",
  "valueExpression": "pageData.PlantType",
  "displayExpression": "converters.ui.translatePicklist(pageData.PlantType, sharedData.__vocabulary.PlantTypeVocab)",
  "selectPage": {
    "itemTitle": "PlantTypeItemTitle",
    "title": "SelectPlantTypeTitle",
    "searchBar": {}
  }
}
```

### `converters.data.escapeGraphQLVariables(value)`
Escapes special characters in a string for safe embedding in GraphQL filter expressions. Used in `onlineMode` filter strings.

## Formatting display values

Date, Time, Boolean and Decimal fields render raw in locale strings (`1980-05-12`, `09:00:00.000`, `true`, `1250.5`). Format them in `en.json`.

Each `${...}` in a locale string is evaluated as a JavaScript expression, so ternaries and `Number(...)` work. The parser ends the expression at the first `}`, so never put a `}` inside one.

In locale strings and expressions, `dateFormat`, `timeFormat` and `dateTimeFormat` are shortcuts to the synchronous converters and take a format string:
- `dateFormat(value, timezoneType, 'YEAR|MONTH|DAY')` — options `YEAR`, `MONTH`, `DAY`, `WEEKDAY`.
- `timeFormat(value, timezoneType, 'HOUR|MINUTE')` — options `HOUR`, `MINUTE`, `SEC`, `TIMEZONE`.
- `timezoneType`: use `'none'` for date-only and time-only fields. Do not invent other values.

Recipes (each guards against null):
```json
{
  "DueDateText": "${pageData.DueDate ? dateFormat(pageData.DueDate, 'none', 'YEAR|MONTH|DAY') : ''}",
  "ArrivalTimeText": "${pageData.ArrivalTime ? timeFormat(pageData.ArrivalTime, 'none', 'HOUR|MINUTE') : ''}",
  "IsUrgentText": "${pageData.IsUrgent == null ? '' : (pageData.IsUrgent ? 'Yes' : 'No')}",
  "UnitPriceText": "${pageData.UnitPrice != null ? '$' + Number(pageData.UnitPrice).toFixed(2) : ''}"
}
```
In a list `itemLayout` string, use `item.` in place of `pageData.`. These shortcuts differ from `converters.date.*` inside custom functions (see [Frontend helpers](./custom-function/cf-frontend-helpers.md#convertersdate)).

## Binding Examples

### Simple Data Binding
```json
{
  "type": "textEditor",
  "title": "FieldLabel",
  "valueExpression": "formData.JobDetails.Description"
}
```
In this example, `FieldLabel` is a localized key defined in `en.json`.

### Expression in `showIfExpression`
```json
{
  "type": "section",
  "title": "AdditionalInfo",
  "showIfExpression": "formData.JobDetails.Status == 'Complete'",
  "items": []
}
```

### List Layout Binding (in `list` page)
```json
{
  "itemLayout": {
    "type": "titleAndCaption",
    "title": "ItemNameKey",
    "caption": "ItemQtyKey"
  }
}
```
In `en.json`:
```json
{
  "ItemNameKey": "${item.Product.Name}",
  "ItemQtyKey": "Qty: ${item.Qty}"
}
```

## Regular Expression Validation

MEX provides a built-in function `isRegexValid` for validating input values against regex patterns. This is useful for validating emails, phone numbers, URLs, or any custom format.

### `isRegexValid(stringToValidate, regexKey)`

- **`stringToValidate`** (`string`): The data expression pointing to the value to validate (e.g., `pageData.Email`).
- **`regexKey`** (`string`): A key reference to a predefined regular expression in the `regex.js` file.
- **Returns**: `boolean` — `true` if the value matches the regex, `false` otherwise.

### `regex.js` File

You must define your regex patterns in a file located at `mex_definition/static_resources/regex.js`. This file exports a `regex` object mapping key names to JavaScript `RegExp` literals.

```javascript
const regex = {
    emailRegex: /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/,
    urlRegex: /^(https?):\/\/[^\s/$.?#].[^\s]*$/i,
    phoneRegex: /^\+?[0-9]{7,15}$/
}

module.exports = regex
```

### Usage in Validators

Use `isRegexValid` in `validator` expressions (component-level or page-level `upsert.validator`):

```json
{
  "type": "textEditor",
  "title": "EmailLabel",
  "valueExpression": "pageData.Email",
  "mandatory": true,
  "validator": [
    {
      "type": "expression",
      "expression": "pageData.Email",
      "errorMessage": "EmailRequired"
    },
    {
      "type": "expression",
      "expression": "isRegexValid(pageData.Email, 'emailRegex')",
      "errorMessage": "InvalidEmailFormat"
    }
  ]
}
```

In `en.json`:
```json
{
  "EmailRequired": "Email is required",
  "InvalidEmailFormat": "Please enter a valid email address"
}
```

### Error Handling

If the `regexKey` does not correspond to any predefined regular expression in the `regex.js` file, `isRegexValid` will throw a runtime error. Always ensure the key exists in `regex.js`.

## Best Practices

- **Keep Expressions Simple**: Complex logic should be avoided in JSON expressions.
- **Null Safety**: MEX expressions generally handle nulls gracefully, but be cautious with deep paths.
- **Performance**: Minimize the number of expressions on a single page for faster rendering.
- **Localization Keys**: Always use pure string keys (no `${}`) for text labels. Use `en.json` to define their content, including any dynamic `${...}` parts.
- **Regex Keys Must Exist**: When using `isRegexValid`, always verify the regex key is defined in `mex_definition/static_resources/regex.js`. A missing key causes a runtime error.
