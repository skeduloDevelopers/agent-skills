# Online Mode — List Page

Read `online-mode.md` and `online-mode-queries.md` first.

A list page in online mode swaps its local data source for live REST queries. This file covers list-page specifics: list source, single-item refresh, search, pagination.

## The `onlineMode` block

Goes inside a list page's definition.

```json
"onlineMode": {
  "list": { /* list query — required */ },
  "item": { /* single-item query — optional */ }
}
```

The list source binds to `pageData.__listOnlineSource` automatically. You don't reference it explicitly — the list page's `itemLayout` reads `item.*` as usual.

## List query

Fetches the list itself. Standard or custom.

### Standard list query

```json
"onlineMode": {
  "list": {
    "type": "standard",
    "objectName": "JobProducts",
    "fields": ["UID", "ProductId", "Product.Name", "Qty", "CreatedDate"],
    "filter": "JobId == '${cf.escape(metadata.contextObjectId)}'",
    "orderBy": "CreatedDate DESC",
    "requestKey": "refreshJobProducts"
  }
}
```

Standard list query fields:

- `objectName` — Skedulo schema object.
- `fields` — fields to fetch.
- `filter` — optional GraphQL filter (escape user input).
- `orderBy` — optional. **Use this, not the page-level `orderBy`** (see "orderBy limit" below).
- `requestKey` — optional. Lets other operations trigger a refresh.

### Custom list query

```json
"onlineMode": {
  "list": {
    "type": "custom",
    "function": "cf.getJobAllocations('scheduled')",
    "requestKey": "refreshJobAllocations"
  }
}
```

Custom list queries return an extended object that includes pagination hooks (see "Pagination" below).

## `orderBy` limit

When the **list query** has an `orderBy`, pagination is **disabled** and the maximum result size is **200 rows**. The platform fetches all matching rows up to 200 in one call.

If you need:

- **Stable sort order** without pagination → put `orderBy` in the list query and accept the 200-row cap.
- **Pagination** with arbitrary order → omit `orderBy` from the list query (rows return in server's natural order) and use search to narrow the result set.
- **More than 200 rows with sort** → use a custom list query and implement pagination yourself (see below).

The `orderBy` on the list page **component** (UI-level sort control) is **disabled in online mode** — it doesn't re-issue the query. To support user-driven sort, add a sort field to your search filter and rebuild the query in a custom function.

## Single-item query

Optional. Fetches one item from the list by its key — useful after an update so the user sees fresh data without a full list reload.

```json
"onlineMode": {
  "list": { /* ... */ },
  "item": {
    "type": "custom",
    "function": "cf.getJobProductItem(args.UID)",
    "requestKey": "refreshJobProductItem"
  }
}
```

Behaviour:

- Not called automatically — only fires when an operation explicitly triggers `refreshJobProductItem` via `reloadRequests`.
- Runs **asynchronously** — the user keeps interacting; the row updates when the fetch resolves.
- Receives `args` from the trigger (so the caller passes `UID`).

If `item` is omitted and a single-item refresh is requested, the platform falls back to re-fetching the whole list.

### Pairing item refresh with upsert

```json
// flat page that edits a single item
"upsert": {
  "onlineMode": {
    "query": { "type": "custom", "function": "cf.saveJobProductItem(pageData)" },
    "reloadRequests": [
      {
        "key": "refreshJobProductItem",
        "args": { "UID": "${pageData.UID}" }
      }
    ]
  }
}
```

After save, the single-item query fires with the saved UID. The list updates that one row in place.

## Search

Online list pages support a search bar that re-fetches data based on what the user types.

```json
"search": {
  "onlineSearch": {
    "hasDefaultSearchBar": true,
    "placeholder": "JobProductListPages.SearchPlaceholder",
    "defaultData": { "StartQty": 0, "EndQty": 50 },
    "ui": {
      "items": [
        {
          "type": "textEditor",
          "valueExpression": "filter.BatchNumber",
          "keyboardType": "number-pad"
        }
      ]
    }
  }
}
```

Fields:

- `hasDefaultSearchBar` — boolean. Show the built-in search bar at the top of the list.
- `placeholder` — localised key for the search bar's placeholder.
- `ui` — optional. An advanced-search panel built from standard editor components, the user opens via a filter icon.
- `ui.items` — list of editor components (text, select, date, toggle, etc.). Their `valueExpression` writes into `filter.<field>`.
- `defaultData` — initial values for the `filter` data context.

Search values are stored in the `filter` data context. Reference them in your list query:

```json
"onlineMode": {
  "list": {
    "type": "standard",
    "objectName": "JobProducts",
    "fields": ["UID", "Product.Name", "Qty", "BatchNumber"],
    "filter": "${cf.buildJobProductFilter(metadata.contextObjectId, filter)}",
    "orderBy": "CreatedDate DESC"
  }
}
```

```javascript
function buildJobProductFilter(jobId, filter) {
  let result = `JobId == '${jobId}'`
  if (filter?.searchText) {
    result += ` AND (Product.Name LIKE '%${filter.searchText}%' OR Product.Description LIKE '%${filter.searchText}%')`
  }
  if (filter?.BatchNumber) {
    result += ` AND BatchNumber == '${filter.BatchNumber}'`
  }
  return result
}
```

When the user types in the search bar or changes the advanced filter, the platform re-runs the list query with the updated `filter` context.

## Pagination (custom list queries)

For more than 200 rows or non-Skedulo data, use a custom list query with state-based pagination.

```javascript
function getJobAllocationsConfig(type) {
  return {
    getBaseAxiosRequestConfig: (currentData, stateData) => ({
      baseURL: "https://api.example.com",
      method: "POST",
      url: "/jobAllocations/get-list",
      data: {
        cursor: stateData,
        scheduledJob: type === 'scheduled',
        limit: 50,
      },
    }),
    onSaveStateData: (currentData, response) => response?.paging?.lastCursor,
    determineLoadMore: (currentData, response) => response?.paging?.hasNextData ?? false,
  }
}
```

Required fields beyond the base shape:

| Field | Receives | Returns | Purpose |
|---|---|---|---|
| `getBaseAxiosRequestConfig(currentData, stateData)` | items already loaded, last saved state | axios config | Build the next request. Use `stateData` for cursor / page tokens. |
| `onSaveStateData(currentData, response)` | items already loaded, the latest response | any | Pulled out of `response` and saved for the next call. Typically a cursor. |
| `determineLoadMore(currentData, response)` | items already loaded, the latest response | `boolean` | Should the platform request more? `false` stops paging. |

Flow:

```text
1. Initial load: stateData = undefined.
2. getBaseAxiosRequestConfig(currentData=[], stateData=undefined) → fire request.
3. Response comes back.
4. onSaveStateData(currentData=[], response) → returns nextCursor.
5. determineLoadMore(currentData=[], response) → returns true.
6. Platform calls getBaseAxiosRequestConfig(currentData=[items], stateData=nextCursor) → fire next request.
7. ... repeat until determineLoadMore returns false or the user stops scrolling.
```

The user can scroll, the platform calls these in the right order. You don't manage the loop yourself.

## Refresh from outside

A list with `requestKey` can be refreshed by any operation that fires `reloadRequests`:

```json
"upsert": {
  "onlineMode": {
    "query": { "type": "custom", "function": "cf.addProduct(pageData)" },
    "reloadRequests": [
      { "key": "refreshJobProducts" }
    ]
  }
}
```

A whole-list refresh resets pagination — only the first page is fetched, and the user is scrolled back to the top.

## Combining patterns

Typical online list page:

```json
{
  "type": "list",
  "title": "JobProductListPages.Title",
  "search": {
    "onlineSearch": {
      "hasDefaultSearchBar": true,
      "placeholder": "JobProductListPages.SearchPlaceholder"
    }
  },
  "onlineMode": {
    "list": {
      "type": "standard",
      "objectName": "JobProducts",
      "fields": ["UID", "Product.Name", "Qty", "BatchNumber", "CreatedDate"],
      "filter": "${cf.buildJobProductFilter(metadata.contextObjectId, filter)}",
      "orderBy": "CreatedDate DESC",
      "requestKey": "refreshJobProducts"
    },
    "item": {
      "type": "standard",
      "objectName": "JobProducts",
      "fields": ["UID", "Product.Name", "Qty", "BatchNumber", "CreatedDate"],
      "filter": "UID == '${cf.escape(args.UID)}'",
      "requestKey": "refreshJobProductItem"
    }
  },
  "itemLayout": {
    "title": "JobProductListPages.ItemTitle",
    "caption": "JobProductListPages.ItemCaption"
  }
}
```

This page has:

- A standard list query with search-driven filter and a fixed `orderBy` (200-row cap).
- A standard single-item query for in-place row refresh after edit.
- Distinct `requestKey`s for whole-list vs single-item refresh.

## Common mistakes

- **Setting `orderBy` on both the list query and the page-level component.** The page-level one is ignored in online mode — only the list query's `orderBy` matters.
- **Hitting the 200-row cap silently.** If `orderBy` is set and the user expects more than 200 rows, you have a UX problem. Either remove `orderBy` (server's order, with pagination) or implement custom pagination.
- **Forgetting `defaultData`** when an advanced search has range filters (start / end). Without defaults, the filter expression evaluates with `undefined` and the `cf.` filter-builder breaks.
- **Searching across un-indexed fields.** A `LIKE '%text%'` filter on a million-row table is slow. Either limit by parent ID first, add an indexed prefix search, or push search to your custom backend.
- **Triggering a single-item refresh without the matching `args`.** `cf.getJobProductItem(args.UID)` reads `args.UID` — if the trigger doesn't pass `args`, you'll fetch with `undefined` and either get nothing or an error.
