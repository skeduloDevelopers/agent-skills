## ExtHelper

Injected into custom functions as the second argument: `(args, { dataContext, extHelpers })`.

### `extHelper.data`

| Method | Signature | Description                                                                                                                                                                                |
|--------|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------||
| `changeData` | `(fn: () => void, options?)` | Change data in data context. Mutate MobX observables safely inside `runInAction`. Pass `{ notifyDataChanged: true }` to trigger draft save. **Always use this instead of direct mutation.** |
| `submit` | `(options?) => Promise<boolean>` | Submit (submit data of this page and go back) the current page. Pass `{ stopWhenInvalid: true }` to abort on validation failure.                                                           |
| `translate` | `(key: string, args?: any[]) => string` | Resolve a localization key, with optional string-format args.                                                                                                                              |
| `getBaseUrl` | `() => string` | Returns the base URL of this environment.                                                                                                                                                  |
| `getAccessToken` | `() => string` | Returns the current access token.                                                                                                                                                          |
| `getIdToken` | `() => string` | Returns the current Id token.                                                                                                                                                              |
| `getTimezonesData` | `() => TimezoneMetadata \| undefined` | Returns timezone metadata.                                                                                                                                             |

**Example — mutate data:**
```typescript
extHelpers.data.changeData(() => {
    dataContext.formData.Jobs[0].Status = "Complete"
}, { notifyDataChanged: true })
```

**Example — submit page:**
```typescript
const success = await extHelpers.data.submit({ stopWhenInvalid: true })
```

**Example — translate with args:**
```typescript
extHelpers.data.translate("some.key", ["value1", "value2"])
```

---

### `extHelper.date`

| Method | Signature | Description |
|--------|-----------|-------------|
| `getNowDateTime` | `() => string` | Current UTC datetime as ISO string. |
| `getLocaleDateDisplay` | `(value, type, timezone?, dateFormatStr?, timeFormatStr?) => string \| undefined` | Format an ISO datetime string for display using the device locale. |

**`getLocaleDateDisplay` details:**
- `type`: `"date"` | `"datetime"` | `"time"`
- `timezone`: optional `TimeZoneType` (e.g. `"job"`, `"resource"`, or a timezone name string)
- `dateFormatStr`: pipe-separated options — `"YEAR"`, `"MONTH"`, `"DAY"`, `"WEEKDAY"` (default: `"MONTH|DAY|WEEKDAY"`)
- `timeFormatStr`: pipe-separated options — `"HOUR"`, `"MINUTE"`, `"SEC"`, `"TIMEZONE"` (default: `"HOUR|MINUTE"`)

**Example:**
```typescript
extHelpers.date.getLocaleDateDisplay("2024-03-15T09:00:00Z", "datetime", "job", "YEAR|MONTH|DAY", "HOUR|MINUTE")
// → "Friday, March 15, 2024 at 09:00 AM"
```

---

### `extHelper.ui`

| Method | Signature | Description |
|--------|-----------|-------------|
| `alert` | `(message: string) => void` | Show a native alert dialog. |

---

## Converters

Injected into custom functions as the second argument: `(args, { dataContext, extHelpers, converters })`.


### `converters.date`

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `dateFormat` | `(value, timezoneType?)` | `Promise<string>` | Async wrapper — use `dateFormatV2` for sync. |
| `dateFormatV2` | `(value, timezoneType?, dateFormatStr?)` | `string` | Sync date formatting. |
| `timeFormat` | `(value, timezoneType?)` | `Promise<string>` | Async wrapper — use `timeFormatV2` for sync. |
| `timeFormatV2` | `(value, timezoneType?, timeFormatStr?)` | `string` | Sync time formatting. |
| `dateTimeFormat` | `(value, timezoneType?)` | `Promise<string>` | Async wrapper — use `dateTimeFormatV2` for sync. |
| `dateTimeFormatV2` | `(value, timezoneType?, dateFormatStr?, timeFormatStr?)` | `string` | Sync datetime formatting. |


**Example:**
```typescript
const display = converters.date.dateFormatV2("2024-03-15", undefined, "YEAR|MONTH|DAY")
// → "March 15, 2024"
```

---

### `converters.localization`

| Method | Signature | Description |
|--------|-----------|-------------|
| `translate` | `(key: string) => string` | Resolve a localization key. No arg substitution — use `extHelper.data.translate` for that. |

---

### `converters.data`

| Method | Signature | Description |
|--------|-----------|-------------|
| `isTempUID` | `(obj: BaseStructureObject) => boolean` | Returns `true` if the object was created locally and not yet synced (has `__isTempObject`). |
| `isCreatingNewObject` | `(obj: BaseStructureObject) => boolean` | Returns `true` if the object is in creation state (`__isCreatingNewObject`). |
| `nowISO` | `(mode?, offsetByTimezone?) => string` | Current time as ISO string. `mode`: `"date"` returns `YYYY-MM-DD`, `"datetime"` (default) returns full ISO. Optional timezone offset. |
| `getValueFromArrayObject` | `(array, compareKey, compareValue, propertyToFetch) => any` | Find a single item in an array by a key/value match, then return a specific property. Throws if multiple matches found. |
| `escapeGraphQLVariables` | `(value: string \| undefined) => string` | Escapes single quotes for safe use in GraphQL queries (replaces `'` with `\'`). |

**Example — find in array:**
```typescript
const name = converters.data.getValueFromArrayObject(
    dataContext.sharedData.resources,
    "UID",
    "resource-uid-123",
    "Name"
)
```

**Example — now as date only:**
```typescript
const today = converters.data.nowISO('date')
// → "2024-03-15"
```

---

### `converters.ui`

| Method | Signature | Description |
|--------|-----------|-------------|
| `joinArrayToStr` | `(array: any[], symbol?: 'comma' \| '' \| 'dot') => string` | Join array to a string. Default separator is `", "`. `"dot"` uses `". "`. Empty string uses no separator. |
| `translatePicklist` | `(value: string, vocabValue: [{Label, Value}]) => string` | Map a picklist raw value to its display label. Returns the original value if no match or label is empty. |

**Example — joinArrayToStr:**
```typescript
converters.ui.joinArrayToStr(["Apple", "Banana", "Cherry"], "comma")
// → "Apple, Banana, Cherry"
```

**Example — translatePicklist:**
```typescript
converters.ui.translatePicklist("active", [
    { Value: "active", Label: "Active" },
    { Value: "inactive", Label: "Inactive" }
])
// → "Active"
```

---

## TimeZoneType

`TimeZoneType` is from `@skedulo/mex-engine-proxy`. It can be:
- `"job"` — timezone of the current job context
- `"resource"` — timezone of the resource
- A raw IANA timezone string (e.g. `"America/New_York"`)
- `undefined` — device local timezone

---

## Custom Function Signature

Custom functions receive:

```typescript
import Converters from "./Converters";

function myFunction(args: any, {dataContext, extHelpers, converters, libraries: {moment}}: {
    dataContext: PageLevelDataContext,
    extHelpers: ExtHelper,
    converters: Converters,
    libraries: {
        moment: Moment
    }
}) {
    // args = the arguments passed from the expression cf.myFunction(...)
    // dataContext = { formData, pageData, sharedData, metadata }
    // extHelpers = ExtHelper (see above)
    // converters = Converters (see above)
    // moment = Moment: the Moment library (https://momentjs.com/)
}
```