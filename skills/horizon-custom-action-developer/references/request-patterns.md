# Custom Action Request Patterns

Working `request` + `executionMode` combinations, each based on an action that runs on a Skedulo
tenant (the connected-function body is simplified). Confirm every object, field, and mutation on the
target tenant before reusing one.

## GraphQL mutation for all selected records (bulk)

One request, one aliased mutation per record. Inside the JSON string, GraphQL quotes are `\\\"`.

```json
{
  "request": {
    "method": "POST",
    "url": "{{ skeduloApi }}/graphql/graphql",
    "body": "{\"query\":\"mutation activateReasonCodes { schema { {% for item in items -%} _j{{loop.index}}: updateReasonCodes(input: { UID: \\\"{{ item.UID }}\\\", IsActive: true }) {%- endfor -%} }}\"}",
    "headers": { "Authorization": "Bearer {{ skeduloJwt }}", "Content-Type": "application/json" }
  },
  "executionMode": { "type": "bulk" },
  "limit": 30
}
```

- Set `limit` so a large selection can't build an oversized mutation.
- For many records, use `{"type": "batch", "batchSize": 50}` with the same body: each window gets its
  own `items`.
- GraphQL errors come back with HTTP 200 and count as success, however simple the mutation. Pass the
  response through with `"successResultTemplate": {"template": "{{ bodyJson | json_encode }}",
  "contentType": "APPLICATION_JSON"}` and have the success dialog check it before claiming the change:

  ```text
  {% set r = successResults | first %}{% if r and r.data and r.data.errors %}Not completed: {{ r.data.errors[0].message }}{% else %}{{ successCount }} record(s) updated.{% endif %}
  ```

  Customer actions read `successResults[].data` the same way. This dialog check has not been run end
  to end, so try it on a test record that fails.

## Call a connected function (bulk)

Send the selected UIDs as a JSON array. `json_encode` produces valid JSON whatever the values contain.

```json
{
  "request": {
    "method": "POST",
    "url": "{{ skeduloApi }}/function/event-queue-handler/event-queue-handler/retry",
    "body": "{% set uids = [] %}{% for item in items %}{% set _ = uids.append(item.UID) %}{% endfor %}{{ uids | json_encode }}",
    "headers": { "Authorization": "Bearer {{ skeduloJwt }}", "Content-Type": "application/json" }
  },
  "executionMode": { "type": "bulk" },
  "limit": 50
}
```

## Call a platform API with a JSON body (single)

One request per record. The platform's own `activate-user` action uses this shape.

```json
{
  "request": {
    "method": "POST",
    "url": "{{ skeduloApi }}/customer/team/users/activate",
    "body": "{% set request = {\"userIds\": [ id ]} %}{{ request | json_encode }}",
    "headers": {
      "Accept": "application/json",
      "Authorization": "Bearer {{ skeduloJwt }}",
      "Content-Type": "application/json"
    }
  },
  "executionMode": { "type": "single", "failureMode": "CANCEL_ON_FAILURE" }
}
```

## Delete through the query API (single)

`args.resourceId` comes from the list or page that runs the action.

```json
{
  "request": {
    "method": "DELETE",
    "url": "{{ skeduloQueryApi }}/query/v1/objects/{{ args.resourceId }}/{{ id }}",
    "headers": { "Authorization": "Bearer {{ skeduloJwt }}" }
  },
  "executionMode": { "type": "single", "failureMode": "CONTINUE_ON_FAILURE" }
}
```

## Choosing an execution mode

| Mode | Requests | Bindings | Use when |
|---|---|---|---|
| `single` | one per record | `id`, `key`, `item`, `args` | The endpoint takes one record, or each record must succeed or fail on its own |
| `bulk` | one for all | `ids`, `keys`, `items`, `args` | The endpoint takes a list and the selection is small (set `limit`) |
| `batch` | one per `batchSize` records | same as bulk, per window | The endpoint takes a list and selections can be large |

`CANCEL_ON_FAILURE` stops at the first failed record; `CONTINUE_ON_FAILURE` runs the rest.

## Things that look right but are wrong

- `{{ item.UID }}` in a bulk URL or body outside a `{% for item in items %}` loop — renders empty.
- `{{ items }}` in a single action — renders empty.
- `"executionMode": {"type": "batch", "batchSize": 0}` — upserts, then every run fails.
- `?access_token={{ skeduloJwt }}` in the URL — leaks the token into logs.
- `Bearer {{ skeduloJwt }}` sent to an external host — hands the user's Skedulo token to a third party.
- Unescaped `"` in a GraphQL string inside `body` — breaks the JSON; use `\\\"` or `json_encode`.
- An action with no `{"name": "UID", "isPrimaryKey": true}` field — every run fails.
