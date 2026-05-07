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
    - Format: `{"Key": "${expression}"}`.
    - Similar to `en.json`, expressions here are wrapped in `${...}` to be evaluated before being passed to the next page as `pageData`.

## Supported Operators

MEX supports a limited set of operators. **Do not use unsupported operators or deeply nested groupings.**

- **Comparison**: `==` (Equals), `!=` (Not Equals), `>` (Greater), `>=` (Greater/Equals), `<` (Less), `<=` (Less/Equals)
- **Logical**: `&&` (AND), `||` (OR)
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
- Used ONLY in `en.json` to refer to the current item being rendered in a `list` page's `itemLayout`.
- Example in `en.json`: `"ItemName": "${item.Name}"`

### `pageData`
- Used to access data local to the current page.
- **Navigation Flow**: When navigating from a `list` to a `flat` page (via `itemClickDestination`), the selected item's data is automatically passed to the next page as `pageData`.
- **Edit Binding**: On the destination page, use `pageData.FieldName` for data binding. Mutations on `pageData` are automatically synchronized with the source array in `formData`.
- **CRITICAL**: Do NOT use `formData.Array[index]` for editing list items. Always use `pageData`.

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

## Best Practices

- **Keep Expressions Simple**: Complex logic should be avoided in JSON expressions.
- **Null Safety**: MEX expressions generally handle nulls gracefully, but be cautious with deep paths.
- **Performance**: Minimize the number of expressions on a single page for faster rendering.
- **Localization Keys**: Always use pure string keys (no `${}`) for text labels. Use `en.json` to define their content, including any dynamic `${...}` parts.
