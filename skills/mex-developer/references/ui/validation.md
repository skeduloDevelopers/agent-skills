# Validation

Validation rules can be applied at two levels:
1. **Component-level** — on individual editor components via the `validator` property. Validates in real-time as the user types or changes values.
2. **Page-level** — inside `upsert.validator`. Runs when the user presses the Save/Add/Update button. Use for cross-field validation or checks that span multiple components.

Both use the same rule format: an **array** of validation rule objects.

## Validation Rule Format

Each rule in the array has:
- `type`: Must be `"expression"`.
- `expression`: An expression that must return `true` for the value to be valid. If it returns `false` (or falsy), the `errorMessage` is shown.
- `errorMessage`: Localized key for the error message displayed to the user.

## Required Field Pattern

To make a field required, combine `mandatory` (for the visual asterisk) with a `validator` rule that checks the value is truthy:

```json
{
  "type": "textEditor",
  "title": "CustomerNameLabel",
  "valueExpression": "pageData.CustomerName",
  "mandatory": true,
  "validator": [
    {
      "type": "expression",
      "expression": "pageData.CustomerName",
      "errorMessage": "CustomerNameRequired"
    }
  ]
}
```
*(In `en.json`: `"CustomerNameRequired": "Customer name is required"`)*

## Custom Validation Pattern

For value constraints (e.g., numeric range, comparison):

```json
{
  "type": "textEditor",
  "title": "QuantityLabel",
  "keyboardType": "number-pad",
  "valueExpression": "pageData.Qty",
  "mandatory": true,
  "validator": [
    {
      "type": "expression",
      "expression": "pageData.Qty",
      "errorMessage": "QuantityRequired"
    },
    {
      "type": "expression",
      "expression": "pageData.Qty > 0",
      "errorMessage": "QuantityMustBeAbove0"
    }
  ]
}
```
*(In `en.json`: `"QuantityRequired": "Quantity is required"`, `"QuantityMustBeAbove0": "Quantity must be greater than 0"`)*

## Select Editor Required Pattern

For select/dropdown fields, validate the bound value field:

```json
{
  "type": "selectEditor",
  "title": "ProductLabel",
  "sourceExpression": "sharedData.Products",
  "displayExpression": "pageData.Product.Name",
  "valueExpression": "pageData.ProductId",
  "structureExpression": "pageData.Product",
  "mandatory": true,
  "validator": [
    {
      "type": "expression",
      "expression": "pageData.ProductId",
      "errorMessage": "ProductRequired"
    }
  ]
}
```

## Regex Validation Pattern

For format validation (e.g., email, phone number, URL), use the built-in `isRegexValid` function. This requires a `regex.js` file in `mex_definition/static_resources/` with predefined patterns. See [Expressions & Binding - Regular Expression Validation](../expressions-binding.md#regular-expression-validation) for full details on `regex.js`.

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
*(In `en.json`: `"EmailRequired": "Email is required"`, `"InvalidEmailFormat": "Please enter a valid email address"`)*

*(In `regex.js`:)*
```javascript
const regex = {
    emailRegex: /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/
}
export default regex
```

## Page-Level Validation (upsert.validator)

Use `upsert.validator` for validation that runs on save — typically cross-field checks:

```json
{
  "type": "flat",
  "title": "EditPageTitle",
  "upsert": {
    "insertTitle": "AddRecordTitle",
    "updateTitle": "EditRecordTitle",
    "validator": [
      {
        "type": "expression",
        "expression": "pageData.EndDate > pageData.StartDate",
        "errorMessage": "EndDateMustBeAfterStart"
      }
    ]
  },
  "items": [...]
}
```
