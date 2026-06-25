# Authentication & Calling APIs

How to call your custom-function backend, Skedulo's GraphQL API, or any other authenticated endpoint from a MEXWEX form.

## The auth primitive

```typescript
const { accessToken, apiUrl, userId } = await mexBridge.getAuthenticationInfo()
```

- `accessToken` — bearer token for the current Skedulo user. Pass as `Authorization: Bearer ${accessToken}`.
- `apiUrl` — the tenant's API base URL (e.g. `https://api.your-tenant.skedulo.com`). Use as the prefix for backend calls.
- `userId` — current user ID, sometimes useful for client-side logging or filtering.

**Treat as fresh-on-call.** Tokens may rotate during a long session. Don't cache for the whole session — fetch when you need to call.

```jsx
async function authenticatedFetch(path, init = {}) {
  const { accessToken, apiUrl } = await mexBridge.getAuthenticationInfo()
  return fetch(`${apiUrl}${path}`, {
    ...init,
    headers: {
      ...init.headers,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  })
}
```

## Calling your custom-function backend

A MEXWEX form often pairs with a **custom-function** backend (Node.js handlers under `custom_functions/`) that runs server-side logic — GraphQL queries against Skedulo, third-party API calls, business rules, etc.

The web side calls these endpoints over HTTPS. The URL convention is:

```text
${apiUrl}/function/{defId}/mex/{path}
```

- `{defId}` — `defId` from your form's `upload_config.json`.
- `{path}` — the path your backend handler registered (e.g. `'job-products'`).

Example:

```jsx
const DEF_ID = 'stripe_default'                                          // matches upload_config.json defId

function buildMexUrl(apiUrl, functionPath) {
  return `${apiUrl}/function/${DEF_ID}/mex/${functionPath}`
}

async function fetchJobProducts(jobId) {
  const { accessToken, apiUrl } = await mexBridge.getAuthenticationInfo()

  const res = await fetch(buildMexUrl(apiUrl, 'job-products'), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ jobId }),
  })

  if (!res.ok) {
    throw new Error(`fetchJobProducts failed: HTTP ${res.status}`)
  }

  return res.json()
}
```

The MEXWEX skill only covers **calling** these endpoints. To **author** the backend handlers (route registration, GraphQL queries, validation, error responses), use the **`mex-custom-function-builder`** skill in this plugin.

## Calling Skedulo's GraphQL endpoint directly

For simple read-only data needs you can hit Skedulo's GraphQL endpoint without a custom-function intermediary.

```jsx
async function graphql(query, variables = {}) {
  const { accessToken, apiUrl } = await mexBridge.getAuthenticationInfo()

  const res = await fetch(`${apiUrl}/graphql/graphql`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query, variables }),
  })

  if (!res.ok) throw new Error(`GraphQL HTTP ${res.status}`)
  const json = await res.json()
  if (json.errors?.length) throw new Error(json.errors[0].message)
  return json.data
}
```

### Filtering — use the entity's typed `EQLQueryFilter<Entity>` scalar

Skedulo's `filter:` argument is a **per-entity custom scalar** named `EQLQueryFilter<Entity>` (PascalCase plural, matching the field name). The scalar serializes as a SOQL-like string (`"FieldName == 'value'"`) but the variable declaration **must use the exact entity type**, not `String!`.

| Field | Filter type |
|---|---|
| `jobProducts` | `EQLQueryFilterJobProducts` |
| `jobs` | `EQLQueryFilterJobs` |
| `products` | `EQLQueryFilterProducts` |
| `resources` | `EQLQueryFilterResources` |
| `<entityField>` | `EQLQueryFilter<EntityField-PascalCased>` |

If a tenant's schema diverges from this convention, the introspection error is explicit — e.g. `Variable '$filter' of type 'String!' used in position expecting type 'EQLQueryFilterJobProducts'`. **Use the type the error names.**

```jsx
const LIST_QUERY = `
  query ListJobProducts($filter: EQLQueryFilterJobProducts!) {
    jobProducts(filter: $filter, orderBy: "CreatedDate DESC") {
      edges { node { UID Name Quantity CreatedDate } }
    }
  }
`

const data = await graphql(LIST_QUERY, {
  filter: `JobId == '${jobId}'`,   // build the SOQL-like string in JS
})
```

The variable's runtime value is still a string — the typed scalar is what the schema requires for the variable declaration so the server can match it to the field's expected input.

#### Pitfall 1 — `$var` inside a quoted filter string is NOT expanded

This pattern looks plausible and is **wrong**:

```jsx
// ❌ DOES NOT WORK
const QUERY = `
  query ListJobProducts($jobId: String!) {
    jobProducts(filter: "JobId == '$jobId'") { ... }
  }
`
graphql(QUERY, { jobId: 'a0Pxxx' })
```

GraphQL only substitutes `$jobId` where it appears as an **argument value position** (e.g. `filter: $jobId`). Inside the quoted string `"JobId == '$jobId'"` it's just literal characters — the server receives `JobId == '$jobId'` and either errors or returns nothing.

#### Pitfall 2 — don't try to patch with `String.prototype.replace`

```jsx
// ❌ DOES NOT WORK — produces a GraphQL syntax error at the server
QUERY.replace('$jobId', jobId)
```

`String.prototype.replace` with a string pattern replaces only the **first** occurrence, which is the operation signature `query ListJobProducts($jobId: String!)`. The result is `query ListJobProducts(a0Pxxx: String!) { ... }` — invalid GraphQL.

#### Pitfall 3 — `String!` for the filter variable

```jsx
// ❌ Server rejects: "Variable '$filter' of type 'String!' used in position expecting type 'EQLQueryFilterJobProducts'"
query ListJobProducts($filter: String!) {
  jobProducts(filter: $filter, ...) { ... }
}
```

The variable's declared type must be the entity-specific filter scalar, even though the value at runtime is a string.

#### Acceptable shortcut

For a quick one-shot you can build the entire query in JS with `${jobId}` interpolated directly into the filter literal and send no `variables`. Make sure the value can't contain `'` or `\` (Skedulo UIDs are alphanumeric — safe in practice). For anything reused, prefer the typed-variable pattern above.

**Note** — `instanceFetch.json` / `staticFetch.json` for Standard MEX *do* support `$variable` token replacement inside their string filters, because the platform's pre-fetch layer rewrites them before the query is sent. That mechanism is **not** available when you call GraphQL directly from a MEXWEX bundle. From MEXWEX, always do the substitution in JS.

Verify the GraphQL path against your tenant — the route layout can vary. When in doubt, route through a custom-function backend instead, which gives you a stable contract on top of GraphQL.

### GraphQL writes — strict input scoping

When you build the input for an insert / update / upsert mutation, **send only the fields that the requirements explicitly call out as writable**, plus the obvious bookkeeping:

- `UID` — required for an update.
- Foreign keys (e.g. `JobId`, `ProductId`) — required to establish the relationship.
- Each user-edited field listed in the requirements, exactly as the requirements name it (don't translate `Qty` → `Quantity` or vice versa).

Do **not** include "helpful" extras the user didn't ask for. Common over-reaches the build agent has shipped in the past, and what's wrong with them:

| Extra field | Why it's wrong |
|---|---|
| `Name` / display strings copied from a lookup | Often a denormalised cache the server maintains itself; tenants commonly reject writes or it overwrites the server value with a stale client value |
| `CreatedDate`, `LastModifiedDate`, `CreatedById` | Server-managed audit fields; rejected as read-only |
| Computed totals, derived sums, status enums computed client-side | Computed on the server; client values diverge from the source of truth |
| Every field you read in the SELECT, mirrored back into the input | Read sets and write sets are different surfaces; selecting `Product { Name }` does not imply you can write `Name` on the parent record |

Failure modes when you ignore this:

- **Best case:** the schema rejects the write with `Unknown input field 'Name'` or `Field 'Name' is not writable on JobProducts`. Easy to spot.
- **Worst case:** the schema *accepts* the field and silently writes it. The server-maintained denormalised cache is now stale. You won't see this in the form — only in the DB or in another consumer.

This rule applies symmetrically to SELECT sets:

- Don't fetch fields you don't display. Tenants rate-limit and bill on field reads.
- Don't fetch fields that aren't in the documented data model — they may not exist at all and the query will 400.

```jsx
// ❌ Over-reach: Name was not listed as writable in the requirements
const input = {
  UID: editingItem.UID,
  JobId: jobId,
  ProductId: productId,
  Qty: Number(quantity),
  BatchNumber: batchNumber || null,
  Name: productName,                     // not requested — DROP
}

// ✅ Strictly scoped to the writable surface in the requirements
const input = {
  ...(editingItem?.UID ? { UID: editingItem.UID } : {}),
  JobId: jobId,
  ProductId: productId,
  Qty: Number(quantity),
  BatchNumber: batchNumber || null,
}
```

If you genuinely think a field needs to be sent and it isn't in the requirements, **stop and ask** rather than adding it speculatively. The cost of asking is one round-trip; the cost of a silent write is a data-integrity bug that may not surface for weeks.

## Calling third-party APIs

Direct calls to third parties (`api.stripe.com`, etc.) are possible but **strongly discouraged** for anything involving secrets:

- Browser environments can't safely hold secret keys — the form's bundle is shipped to every user's device. Anyone can extract whatever you embed.
- Most third parties' CORS policies block direct browser calls anyway.

**Pattern**: route through your custom-function backend. The backend holds the secret key, calls the third party, and returns a sanitised response to the form.

```text
[MEXWEX form]
   │  POST /function/{defId}/mex/charge
   ▼
[custom-function backend]
   │  Stripe secret key, call stripe.com
   ▼
[third-party API]
```

## Patterns

### Token cached per-render, fetched per-call

```jsx
async function withAuth() {
  // Fetch fresh; if you call this five times in one render, that's still cheap.
  return mexBridge.getAuthenticationInfo()
}
```

Don't store the token in module-level state for "the whole session" — when it rotates, every cached call breaks until next reload.

### Dev fallback

When running `vite` in a desktop browser, `mexBridge.getAuthenticationInfo()` rejects. Detect and fall back to a dev token:

```jsx
async function getAuth() {
  try {
    return await mexBridge.getAuthenticationInfo()
  } catch {
    return {
      accessToken: import.meta.env.VITE_DEV_TOKEN ?? '',
      apiUrl: 'https://dev-api.example.com',
    }
  }
}
```

The fallback only fires off-device. Don't ship dev tokens — gate behind `import.meta.env.DEV` if your build separates dev / prod.

### Retry on transient failure

```jsx
async function fetchWithRetry(url, init, attempts = 2) {
  for (let i = 0; i <= attempts; i++) {
    try {
      const res = await fetch(url, init)
      if (res.ok || res.status < 500) return res
    } catch (e) {
      if (i === attempts) throw e
    }
    await new Promise(r => setTimeout(r, 500 * (i + 1)))
  }
}
```

Retry only on 5xx / network errors, not on 4xx — those are user / contract errors and won't fix themselves.

### Idempotency

For writes that must not duplicate (payments, record creates), pass an idempotency key derived from the operation:

```jsx
await fetch(buildMexUrl(apiUrl, 'create-payment-intent'), {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'Idempotency-Key': `payment-${jobId}-${attempt}`,
  },
  body: JSON.stringify({ jobId, amount }),
})
```

Your backend honours the header (typically by passing it through to the third party's idempotency mechanism, e.g. Stripe).

## Error handling

```jsx
try {
  const data = await fetchJobProducts(jobId)
  setProducts(data.JobProducts)
  setError(null)
} catch (e) {
  setError(e.message)
  setProducts([])
  // Do NOT auto-retry the user-visible flow — surface and let them retry.
}
```

Distinguish:

- **Auth errors (401 / 403)** — usually means the token rotated mid-session. Retry once after re-fetching `getAuthenticationInfo()`. If still failing, surface to the user — they may need to log out and back in.
- **Network errors** — show "no connection, please retry".
- **5xx** — your backend or Skedulo had a hiccup. Retry once or twice with backoff.
- **4xx (other)** — usually a contract violation. Show the message and stop; auto-retry won't help.

## Don't

- Don't put API URLs in `instanceFetch.json` for MEXWEX. That's the offline-cache mechanism — irrelevant here.
- Don't cache the access token in `localStorage`. WebViews share storage across forms; you risk leaking tokens between contexts. Always fetch from the bridge.
- Don't call third-party APIs that require secret keys directly from the bundle. Route through your custom-function backend.
- Don't omit `Content-Type: application/json` on POSTs — some backends 415 without it.
- Don't write `filter: "Field == '$var'"` and pass `{ var: ... }` in `variables` — GraphQL won't substitute inside the quoted string. Build the filter string in JS and pass it as `filter: $filter` with the entity's typed `EQLQueryFilter<Entity>` scalar. See the **Filtering** section above.
- Don't try to fix the above by `query.replace('$var', value)` — `String.prototype.replace` replaces only the first match, which is the operation signature, producing a GraphQL syntax error.
- Don't declare the filter variable as `String!` — the field expects the entity-specific scalar (e.g. `EQLQueryFilterJobProducts!`). Server error reads `Variable '$filter' of type 'String!' used in position expecting type 'EQLQueryFilter<Entity>'` — copy the type from the error.
