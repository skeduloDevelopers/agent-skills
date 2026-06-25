# Online Only Mode

MEX has two execution modes:

- **Offline mode (default)** — data is pre-fetched into the local cache, the user works against the cache, and changes sync back when the user presses Save on the root page.
- **Online Only Mode (`fullOnlineMode`)** — data is fetched and pushed **synchronously** while the form is open. Most CRUD actions hit the server immediately.

This file covers Online Only Mode. For offline behaviour, see the rest of this skill.

## When to use Online Only Mode

Use it when:

- Data must always be **fresh** at the moment the user opens the form (e.g. live inventory, today's price list, dispatcher-controlled queue state).
- Writes must hit the server **immediately** rather than queuing for sync (e.g. the form drives a downstream workflow that other users see).
- The data set is too large to pre-fetch per user.
- The form needs **server-side validation** at the moment of save.

Do NOT use it when:

- Users in the field need to keep working without connectivity. Online mode requires a connection — without one the form refuses to open.
- The form is a simple CRUD on a single record that fits easily in the offline cache.

## How to enable

Two settings, both required:

### `ui_def.json` — `settings.fullOnlineMode`

```json
{
  "settings": {
    "fullOnlineMode": true
  },
  "pages": { /* ... */ },
  "firstPage": "..."
}
```

### `metadata.json` — `isRequiredOnline`

```json
{
  "contextObject": "Jobs",
  "isRequiredOnline": true
}
```

With both set:

- The form will not open without a network connection — the user sees an "internet required" message.
- The platform routes data fetches and pushes through the online pipeline instead of the offline cache.

## Hard rules

1. **Do NOT touch `instanceFetch.json` for CRUD-relevant data.** In online mode, CRUD goes through the queries declared in `ui_def.json` — see `online-mode-queries.md`. If you also put the same data in `instanceFetch.json`, you'll get unexpected behaviour from the two pipelines fighting each other. Empty or near-empty `instanceFetch.json` is the right shape for online forms.
2. **Do NOT mix offline and online in one form.** A form is either fully online (`fullOnlineMode: true` + `isRequiredOnline: true`) or fully offline. There is no "online for some pages, offline for others".
3. **Both settings together.** Setting only one is misconfiguration. `fullOnlineMode: true` without `isRequiredOnline: true` will let users open the form offline and the queries will fail. `isRequiredOnline: true` without `fullOnlineMode: true` blocks offline open but doesn't enable the online pipeline.
4. **Online queries are versioned features.** Verify your platform release supports the query types and properties you use. When in doubt, prototype on a test tenant first.

## What changes vs. offline mode

| Surface | Offline | Online |
|---|---|---|
| Pre-load | `instanceFetch.json` runs at form open | (skip) |
| Page data | Read from `formData` (pre-loaded) | Fetched per-page via `pageDataExpression` (online) |
| List page source | Local filtered slice of `formData` | Live REST fetch with pagination |
| Save / Upsert | Buffered locally, synced on root Save | Sent to server immediately |
| Delete | Buffered locally, synced on root Save | Sent to server immediately |
| Search / Filter (list page) | Filters local items | Fetches new items via query |

## Concept overview

Online Only Mode introduces three new building blocks. Each has its own reference file:

- **Queries** — the shape that declares "fetch this" or "push this". Two flavours: **Standard** (Skedulo GraphQL, no backend code) and **Custom** (your custom-function backend, full control). Two directions: **Fetch** and **Push**. See `online-mode-queries.md`.
- **List page online source** — `pageDataExpression` and `onlineMode` blocks on a list page that drive the list's data. Includes single-item refresh, search, and pagination. See `online-mode-list-page.md`.
- **Refresh keys** — every fetch can register a `requestKey`; pushes can fire a `reloadRequests` list of those keys to refresh dependent data. Covered in `online-mode-queries.md` and `online-mode-list-page.md`.

## Mental model

In offline mode you describe **what data the form needs**, and the platform fetches it once. In online mode you describe **what data each surface needs** (each page header, list, item view), and the platform fetches each on-demand. After a write, you tell the platform **which fetches to redo** so the UI reflects server state.

The shift is from "one big snapshot" to "many small live queries".

## Example: minimal online list form

```json
// ui_def.json
{
  "settings": { "fullOnlineMode": true },
  "pages": {
    "list": {
      "type": "list",
      "title": "JobProductListPages.Title",
      "onlineMode": {
        "list": {
          "type": "standard",
          "objectName": "JobProducts",
          "fields": ["UID", "Product.Name", "Qty"],
          "filter": "JobId == '${cf.escape(metadata.contextObjectId)}'",
          "orderBy": "CreatedDate DESC",
          "requestKey": "refreshJobProducts"
        }
      }
    }
  },
  "firstPage": "list"
}
```

```json
// metadata.json
{
  "contextObject": "Jobs",
  "isRequiredOnline": true
}
```

This list fetches `JobProducts` for the current Job from Skedulo's GraphQL on open, displays them, and exposes a `refreshJobProducts` key that other operations can trigger to refresh the list.

For deeper patterns (custom backends, single-item refresh, search, pagination), see `online-mode-queries.md` and `online-mode-list-page.md`.

## Common mistakes

- **Forgetting `isRequiredOnline`** — the form opens offline, queries fail at runtime, the user is confused.
- **Leaving `instanceFetch.json` populated** — the offline pre-load runs in parallel with online fetches and you get stale or duplicate data.
- **Sharing a `requestKey` between two unrelated fetches** — `reloadRequests` triggers all of them. Pick distinct keys per logical resource.
- **Putting filters in the page-level `orderBy` instead of the query's `orderBy`** — the page-level `orderBy` is disabled in online list pages (see `online-mode-list-page.md`).
- **Hardcoding tenant URLs into a custom function** — your custom function should derive the base URL from the runtime context, not hardcode a tenant.
