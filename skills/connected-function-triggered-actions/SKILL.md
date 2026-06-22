---
name: connected-function-triggered-actions
description: Build connected-function handlers for Skedulo triggered actions — functions called automatically when records are created, updated, or deleted. Use this skill when implementing a `POST /triggered-action/*` route, writing a `*.triggered-action.json` manifest, using `createTriggeredActionHandler`, working with `object_modified` triggers / EQL filters / `previousFields`, or deploying triggered actions with `sked artifacts triggered-action`.
---

# Connected Function — Triggered Actions

Triggered actions fire automatically when Skedulo records change. The platform POSTs the changed records to your function endpoint. Two pieces are required:

1. **A manifest** (`src/triggered-actions/*.triggered-action.json`) — tells Skedulo *when* to fire (trigger type, schema, EQL filter) and *what* to send (`query` for new fields, `previousFields` for old).
2. **A handler** in your function — `createTriggeredActionHandler<T>(objectName, handler)` parses the payload into a typed `TriggerContext` (`newRecords`, `mapOldRecord`, `isInsert/isUpdate/isDelete`).

Route convention: `POST /triggered-action/{entity-action}` — the URL in the manifest must match exactly.

Keep EQL filters narrow, mark slow work `sked-function-execution-type: async`, and deploy the function before the manifest (`sked artifacts triggered-action upsert -f <manifest> -a <alias>`). Always ask for the tenant alias before deploying.

## Full reference

See **[references/triggered-action-handler.md](references/triggered-action-handler.md)** for the complete manifest schema, handler patterns, `TriggerContext` API, and the full CLI workflow (upsert, list, get, delete).

For large record batches that risk timeouts, use the **connected-function-event-queue** skill.
