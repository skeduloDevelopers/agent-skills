# Editor & Layout Components

## Layout Components

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
- `sourceExpression`: Data context path (e.g., `sharedData.Options` or `sharedData.__vocabulary.VocabKey`). Omit when using `onlineMode`.
- `onlineMode`: (Optional) Live server-side search source. See `../online-mode-queries.md` → "Editor `onlineMode`".
- `displayExpression`: For Object/Lookup sources, the full data path to the display field of the selected item (e.g., `pageData.Product.Name` when `structureExpression` is `pageData.Product`). For Picklists, use `converters.ui.translatePicklist(valueExpression, sourceExpression)` to map stored values to display labels (e.g., `converters.ui.translatePicklist(pageData.PlantType, sharedData.__vocabulary.PlantTypeVocab)`).
- `valueExpression`: Binding for the selected value.
- `structureExpression`: (Optional) Binding for the cloned object. **Omit for Picklist/Vocabulary data.**

#### Example (Object Source)
```json
{
  "type": "selectEditor",
  "title": "StatusTitle",
  "sourceExpression": "sharedData.Statuses",
  "displayExpression": "pageData.StatusObject.Name",
  "valueExpression": "pageData.Status",
  "structureExpression": "pageData.StatusObject"
}
```

#### Example (Picklist / Vocabulary Source)
```json
{
  "type": "selectEditor",
  "title": "TypeTitle",
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
*(In en.json: `"PlantTypeItemTitle": "${item.Label}"` - because `item` is a { Label: string, Value: string } in picklists)*

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
Selection component rendered as checkbox, radio, switch, or segment.
- `type`: `"toggleEditor"`
- `mode`: `"checkbox"` | `"radio"` | `"switch"` | `"segment"`
- `items`: Array of toggle items, each with:
    - `valueExpression`: Data binding.
    - `text`: Localized display label key.
    - `onValue` / `offValue`: Values written on toggle on/off. (Not required for `switch`.)

#### Example
```json
{
  "type": "toggleEditor",
  "mode": "checkbox",
  "title": "SymptomsTitle",
  "items": [
    {
      "onValue": true,
      "offValue": false,
      "text": "SoreThroatLabel",
      "valueExpression": "pageData.SoreThroat"
    },
    {
      "onValue": true,
      "offValue": false,
      "text": "HasFeverLabel",
      "valueExpression": "pageData.HasFever"
    }
  ]
}
```
*(For `radio`/`segment`, all items share the same `valueExpression` — selecting one clears the others. For `switch`, omit `onValue`/`offValue`.)*

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

## Common Component Attributes

Applicable to almost all View Components:
- `showIfExpression`: Expression to toggle visibility.
- `readonly`: Expression to toggle read-only state (primarily for editors).
- `title`: Localized string key for the component's label/header (Pure string, no `${}`).
- `caption`: Localized string key for the component's sub-text/description (Pure string, no `${}`).
- `mandatory`: Boolean or expression. **UI-only** — it only shows an asterisk (*) next to the title. It does **NOT** enforce validation. You MUST also add a `validator` rule if you want to actually prevent saving when the field is empty.
- `validator`: Array of validation rule objects for real-time input validation. See [Validation](./validation.md).
