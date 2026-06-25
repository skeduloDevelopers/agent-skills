# Display & Navigation Components

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
