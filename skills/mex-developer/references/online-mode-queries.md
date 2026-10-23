# Online Mode — Queries

Read `online-mode.md` first for context.

A **query** is a JSON block that tells the platform how to fetch or push data over the network. Online Only Mode is built on queries.

## Query taxonomy

Queries split along two axes:

|  | Standard | Custom |
|---|---|---|
| **Fetch** | Skedulo GraphQL via built-in plumbing | Your custom-function endpoint, full control |
| **Push** | Skedulo GraphQL CRUD via built-in plumbing | Your custom-function endpoint, full control |

Pick **Standard** when the data lives in Skedulo's database and the operation is a straight CRUD. Pick **Custom** when you need a different endpoint, custom logic, joined / aggregated data, or any third-party integration.

## Standard fetch

```json
{
  "type": "standard",
  "object": "ObjectName",
  "fields": ["FieldA", "FieldB", "Relationship.FieldC"],
  "filter": "FieldA == '${cf.escape(metadata.contextObjectId)}'"
}
```

Fields:

- `object` — Skedulo schema object name (e.g. `JobProducts`, `Resources`, `Jobs`).
- `fields` — array of fields to return. Dot-paths follow relationships.
- `filter` — optional. Becomes the GraphQL filter. Always pass user / context data through `cf.escape(...)` (see "Filter escaping" below).
- `orderBy` — optional. GraphQL order syntax: `"Name ASC"` or `"CreatedDate DESC, Name ASC"`.

The platform builds a GraphQL query from this declaration and calls Skedulo's API. You write no backend code.

**Limits:**

- You can only fetch from the Skedulo schema.
- You can only return shapes the GraphQL schema supports — no derived / computed fields.

## Custom fetch

```json
{
  "type": "custom",
  "function": "cf.fetchSomeData()"
}
```

The `function` value is a JS expression evaluated by the form runtime. It calls a custom function (the `cf.` prefix) which returns a **custom query return object**.

```javascript
// in your custom-function bundle
function fetchSomeData() {
  return {
    getBaseAxiosRequestConfig: () => ({
      baseURL: "https://api.example.com",
      method: "GET",
      url: "/some/path",
    }),
  }
}
```

`getBaseAxiosRequestConfig` is the only required field. The platform calls your function, reads the axios config, fires the HTTP request, and assigns the response to the target binding.

For calls into **your own** custom-function backend (recommended for anything involving secrets), set `baseURL` from the runtime helper and use the path convention:

```javascript
function fetchSomeData(input, { extHelpers }) {
  return {
    getBaseAxiosRequestConfig: () => ({
      baseURL: extHelpers.data.getBaseUrl(),
      method: "POST",
      url: "/function/{your_def_id}/mex/your-path",
      data: { input },
    }),
  }
}
```

Replace `{your_def_id}` with your form's `defId` from `upload_config.json` and `your-path` with whatever your backend handler registered. See **Authoring a custom-function backend** in the `mex-custom-function-builder` skill for the receiving side.

## Standard push

```json
{
  "type": "standard"
}
```

Used inside `upsert.onlineMode` and `delete.onlineMode` on a flat page. The platform infers the object name and primary key from page context (`pageData.ObjectName`, `pageData.UID`) and constructs the matching GraphQL CRUD call.

Most flat pages can use this if the page is editing a single Skedulo record.

## Custom push

```json
{
  "type": "custom",
  "function": "cf.saveItem(pageData)"
}
```

Returns the same custom query object shape as custom fetch, with optional error handling:

```javascript
function saveItem(pageData) {
  return {
    getBaseAxiosRequestConfig: () => ({
      baseURL: "https://api.example.com",
      method: "POST",
      url: "/items/save",
      data: pageData,
    }),
    determineIfError: (response) => {
      // Optional. Default: HTTP non-2xx is error.
      return response.data?.status === 'failed'
    },
    getErrorMessage: (response, error) => {
      // Optional. Returned message is shown to the user.
      if (error) return { title: "Network error", description: String(error) }
      if (response.data?.message) {
        return { title: "Save failed", description: response.data.message }
      }
      return null
    },
  }
}
```

## Custom Query Return Object — full shape

| Field | Required | When called | Purpose |
|---|---|---|---|
| `getBaseAxiosRequestConfig` | yes | Before each request | Returns axios config: `baseURL`, `method`, `url`, `data`, `params`, `headers`. |
| `determineIfError` | no | After each response | Returns `boolean`. `true` means treat as error even if HTTP status was 2xx. Default: HTTP-status based. |
| `getErrorMessage` | no | If error | Returns `{ title, description }` to show the user. Receives `(response, error)`; `error` is set on network failure. |

These three are the **base** shape for fetch and push. List queries add more fields — see `online-mode-list-page.md`.

## Filter escaping

When you interpolate user / context data into a filter string, escape it. Otherwise apostrophes or special GraphQL characters break the query.

```json
{
  "filter": "ProductName == '${cf.escape(filter.searchText)}'"
}
```

If `searchText` is `O'Hare`, raw interpolation produces `'O'Hare'` — broken syntax. `cf.escape` produces `'O\'Hare'` — valid.

For complex filters, consider building the entire filter string in a custom function:

```json
{ "filter": "${cf.buildAdvancedFilter(metadata.contextObjectId, filter)}" }
```

```javascript
function buildAdvancedFilter(jobId, filter) {
  let result = `JobId == '${jobId}'`
  if (filter?.searchText) {
    result += ` AND (Product.Name LIKE '%${filter.searchText}%')`
  }
  return result
}
```

(Even inside the custom function, escape user input. The example here is illustrative — production code should sanitise.)

## `requestKey` — naming a fetch

Any fetch query can take a `requestKey`:

```json
{
  "type": "standard",
  "object": "JobProducts",
  "fields": ["UID", "Name", "Qty"],
  "filter": "JobId == '${cf.escape(metadata.contextObjectId)}'",
  "requestKey": "refreshJobProducts"
}
```

This name lets other operations refresh this fetch on demand — see "Refresh keys" below.

## `reloadRequests` — refresh after a write

A push operation can fire one or more refreshes after it succeeds:

```json
"upsert": {
  "onlineMode": {
    "query": {
      "type": "custom",
      "function": "cf.saveJobProductItem(pageData)"
    },
    "reloadRequests": [
      { "key": "refreshJobProducts" },
      { "key": "refreshJobProductsHeader" }
    ]
  }
}
```

After `cf.saveJobProductItem` resolves successfully, the platform re-runs every fetch that registered the named keys.

### Passing `args` to a refresh

Some fetches need parameters (e.g. "refresh the single item with this UID"). Pass them via `args`:

```json
"reloadRequests": [
  {
    "key": "refreshJobProductItem",
    "args": { "UID": "${pageData.UID}" }
  }
]
```

The receiving fetch reads `args` from its scope:

```json
{
  "type": "custom",
  "function": "cf.getJobProductItem(args.UID)",
  "requestKey": "refreshJobProductItem"
}
```

## Where queries live

Online queries can appear in several places. Each place has its own shape requirements — refer to the corresponding spec when wiring one.

| Location                                                      | What it does                                                                                      |
|---------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `pageDataExpression.requests[]`                               | Fetches data into `pageData.<target>` for the current page (e.g. a header summary).               |
| `formDataExpression.requests[]`                               | Fetches data into `formData.<target>` at the form level — shared across all pages in the session. |
| List page `onlineMode.list`                                   | The page's main list source — see `online-mode-list-page.md`.                                     |
| List page `onlineMode.item`                                   | A single-item refresh (optional companion to the list source) — see `online-mode-list-page.md`.   |
| Flat page `upsert.onlineMode.query`                           | Push on save / upsert.                                                                            |
| Flat page `delete.onlineMode.query`                           | Push on delete.                                                                                   |
| `selectEditor.onlineMode` (or `multiSelectEditor.onlineMode`) | Remote-fetched options for an selector.                                                           |
| Async validator                                               | Server-side validation while typing.                                                              |
| `dataObserver`                                                | Fetch when a watched expression changes.                                                          |
| Button group `customButton.onlineMode.query`                  | Custom button that fires an API call.                                                             |

Always pair a fetch with at least one location that triggers it — orphan queries do nothing.

### Editor `onlineMode`

Remote-fetched options for `selectEditor` (or `multiSelectEditor`).

Same Standard/Custom shapes as above:
- `objectName` (not `object`)
- Escape with `converters.data.escapeGraphQLVariables(...)` (not `cf.escape`)
- `${filter.searchText}` is the picker's live search-bar input
- Sort via `onlineMode.orderBy` (not `selectPage.orderBy`)

#### Standard fetch
```json
"onlineMode": {
  "type": "standard",
  "objectName": "Accounts",
  "fields": ["UID", "Name", "BillingStreet"],
  "filter": "Name LIKE '%${converters.data.escapeGraphQLVariables(filter.searchText)}%'",
  "orderBy": "Name ASC"
}
```

#### Custom fetch
```json
"onlineMode": { "type": "custom", "function": "cf.fetchAccounts(filter, pageData)" }
```

## Patterns

### Header summary above a list

```json
"pageDataExpression": {
  "requests": [{
    "type": "online",
    "target": "pageData.Header",
    "query": {
      "type": "custom",
      "function": "cf.getListHeader()",
      "requestKey": "refreshHeader"
    }
  }]
}
```

After save, fire `{ "key": "refreshHeader" }` in the upsert's `reloadRequests` to update the header count.

### Form-level shared data

Use `formDataExpression` when multiple pages in the same session need the same reference data. The fetch runs once when the form opens and the result is available in `formData.<target>` on every page.

```json
"formDataExpression": {
  "requests": [{
    "type": "online",
    "target": "formData.Resources",
    "query": {
      "type": "custom",
      "function": "cf.getResources()",
      "requestKey": "refreshResources"
    }
  }]
}
```

Any page can then read from `formData.Resources` without re-fetching. To force a refresh after a write, fire `{ "key": "refreshResources" }` in that page's upsert `reloadRequests`.

### Reactive fetch on field change (`dataObserver` type `online`)

```json
"dataObserver": [{
  "dataExpression": ["PROPERTY_TO_OBSERVE"],
  "request": {
    "type": "online",
    "query": { "type": "custom", "function": "cf.fetchSomething(pageData)" },
    "handler": "cf.applyResponse(query.response, pageData)"
  }
}]
```

### Idempotent save

Custom push that includes an idempotency key:

```javascript
function saveJob(pageData) {
  return {
    getBaseAxiosRequestConfig: () => ({
      baseURL: extHelpers.data.getBaseUrl(),
      method: "POST",
      url: "/function/your_def/mex/save-job",
      headers: { "Idempotency-Key": `save-${pageData.UID}-${pageData.__attempt}` },
      data: pageData,
    }),
  }
}
```

The backend honours the header — replays return the original result without re-executing.

### Conditional reload

Sometimes you only want to refresh a fetch if certain conditions hold. The form's `reloadRequests` list is static, so put the condition inside the receiving fetch's custom function:

```javascript
function refreshHeaderIfStale(currentHeader) {
  if (!currentHeader || isOlderThanFiveMinutes(currentHeader.timestamp)) {
    return { getBaseAxiosRequestConfig: () => ({ /* ... */ }) }
  }
  return { getBaseAxiosRequestConfig: () => null }   // platform skips when null
}
```

(The "return null to skip" shape is platform-version dependent — verify on your tenant.)

## Common mistakes

- **Reusing a `requestKey` for unrelated fetches.** A `reloadRequests` entry triggers all matching keys. Use distinct names per resource.
- **Forgetting `cf.escape`.** Apostrophes in user input crash the GraphQL query.
- **Putting secret keys in custom-function client code.** The `cf.` functions run in the form runtime — secret keys belong in your custom-function **backend**, not in this client side.
- **Returning the wrong shape from a custom function.** Required: `getBaseAxiosRequestConfig`. Optional: `determineIfError`, `getErrorMessage`. Anything else is ignored at best, broken at worst.
- **Mixing online and offline behaviour.** Online queries replace `instanceFetch.json` for online forms — don't try to layer. The custom save feature is offline-only; don't mix it with online mode. 