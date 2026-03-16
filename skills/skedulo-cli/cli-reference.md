# Skedulo CLI Command Reference

## Tenant Commands

| Command | Flags | Needs `-a` |
|---------|-------|------------|
| `sked tenant login web` | `--json`, `-a`, `-d`, `-t`, `-l`, `-u` | Optional (sets alias for new login) |
| `sked tenant login access-token` | `--json`, `-a`, `-l`, `-d` | Optional |
| `sked tenant list` | `--json`, `--columns`, `-x`, `--filter`, `--output`, `--sort` | No |
| `sked tenant display` | `--json`, `-a`, `-r`, `-p` | Yes |
| `sked tenant set-default` | `--json`, `-a` (required) | Yes (required) |
| `sked tenant logout` | (none documented) | No |

## Artifact Commands

All artifact commands follow: `sked artifacts <type> <operation> [flags] -a <alias>`

### Operations by Type

| Type | get | list | upsert | delete | Identifier |
|------|-----|------|--------|--------|------------|
| custom-field | Yes | Yes (`--objectName` required) | Yes | Yes | `--name` + `--objectName` |
| custom-object | Yes | Yes | Yes | Yes | `--name` |
| function | No | Yes | Yes | Yes | `--name` |
| webhook | Yes | Yes | Yes | Yes | `--name` |
| web-extension | No | No | Yes | Yes | `--name` |
| horizon-page | Yes | Yes | Yes | Yes | `--slug` |
| horizon-template | Yes | Yes | Yes | Yes | `--name` |
| triggered-action | Yes | Yes | Yes | Yes | `--name` |
| mobile-extension | No | No | Yes | Yes | `--name` |
| public-page | No | No | Yes | Yes | `--name` |
| user-role | Yes | Yes | Yes | Yes | `--name` |

### Common Artifact Flags

| Flag | Used on | Purpose |
|------|---------|---------|
| `-a <alias>` | All artifact commands | Target tenant (REQUIRED — see Rule 1) |
| `-f <file>` | upsert, create, update | Path to artifact JSON file |
| `-o <dir>` | get | Output directory (only use when modifying) |
| `-w <seconds>` | upsert, delete | Wait timeout (default: 900s) |
| `--json` | All commands | JSON output to stdout |
| `--name <value>` | get, delete, upsert | Artifact identifier |
| `--slug <value>` | horizon-page only | Page identifier (instead of --name) |
| `--objectName <value>` | custom-field only | Required parent object name |

**Note:** `create` and `update` are deprecated on all artifact types. Use `upsert` instead.

## Function Commands (Local Dev)

| Command | Flags | Needs `-a` |
|---------|-------|------------|
| `sked function dev DIRECTORY` | `--json`, `-p`, `-f` | No (local only) |
| `sked function generate -n <name> -o <output>` | `--json` | No (local only) |

## Package Commands

| Command | Flags | Needs `-a` |
|---------|-------|------------|
| `sked package deploy local -p <path>` | `--json`, `-a`, `-v`, `-d` (dryRun), `-i` | Yes |
| `sked package deploy registered -p <name>` | `--json`, `-a`, `-v` (version), `--verbose`, `-i` | Yes |
| `sked package list` | `--json`, `-a`, `-q` | Yes |
| `sked package register -s <source>` | `--json` | No (irreversible!) |

## Web Extension Commands (Local Dev)

| Command | Flags | Needs `-a` |
|---------|-------|------------|
| `sked web-extension dev DIRECTORY` | `--json`, `-h` (host) | No (local only) |

## Artifact Descriptions

Understanding what each artifact represents helps you choose the right one to modify.

**Note:** Artifact availability is tenant-specific. Some types may be in alpha/beta with limited rollout — a type available on dev may not be on UAT. If a command fails unexpectedly, the type may not be enabled on that tenant.

| Artifact | What it is | Key detail |
|----------|-----------|------------|
| **custom-object** | Defines a data schema (like a database table) | Create objects before adding fields to them |
| **custom-field** | A field on a custom object (column on the table) | Types: String, Integer, Decimal, Date, DateTime, Time, Checkbox, Picklist, MultiPicklist, TextArea, URL, Lookup, Has-many |
| **function** | Server-side code that runs on Skedulo's platform (bundled) | JSON metadata + `source` directory with the actual code. Deploy the JSON file, not the directory |
| **horizon-page** | A pointer to a horizon-template — defines the page's name, slug, and published state | To change the page's **UI**, update the **horizon-template** instead |
| **horizon-template** | The actual UI component for a page (bundled) | Contains the React/TypeScript source code. This is what you modify to change what a page looks like |
| **web-extension** | A bundled UI artifact deployed into the Skedulo web app (bundled) | JSON metadata + `source` directory |
| **webhook** | A GraphQL subscription that pushes data to an external URL | The `query` field defines what data is sent; `url` is where it goes |
| **triggered-action** | Fires when data changes and calls a URL (usually a function) | Needs a function URL — discover it via `sked artifacts function list --json` |
| **public-page** | A publicly accessible page (bundled) | No authentication required to access |
| **mobile-extension** | Extends the Skedulo mobile app (bundled) | JSON metadata + `source` directory |
| **user-role** | Defines permissions for a group of users | Uses permission patterns with wildcard support (`skedulo.tenant.*`) |

**Bundled artifacts** (function, horizon-template, web-extension, public-page, mobile-extension) have a `source` field pointing to a directory containing the implementation. Always deploy using the JSON metadata file, not the source directory.

## Artifact JSON Schemas

File naming convention: `{name}.{artifact-type}.json`

Bundled artifacts (functions, horizon-templates, web-extensions, public-pages) have a `source` field pointing to a directory. Deploy using the JSON file, not the directory.

### Custom Object

```json
{
  "metadata": { "type": "CustomObject" },
  "name": "MyObject",
  "label": "My Object",
  "description": "Description of the object"
}
```

### Custom Field

```json
{
  "metadata": { "type": "CustomField" },
  "objectName": "ParentObject",
  "name": "FieldName",
  "field": {
    "type": "String",
    "description": "Field description",
    "display": {
      "label": "Field Label",
      "order": 0,
      "showOnDesktop": true,
      "showOnMobile": true,
      "editableOnMobile": true,
      "requiredOnMobile": false
    },
    "constraints": {
      "required": false,
      "unique": false,
      "accessMode": "ReadWrite",
      "maxLength": 255
    }
  }
}
```

Field types: String, Integer, Decimal, Date, DateTime, Time, Checkbox, Picklist, MultiPicklist, TextArea, URL, Lookup, Has-many.

### Function (Bundled)

```json
{
  "metadata": { "type": "Function" },
  "name": "my-function",
  "source": "./my-function"
}
```

### Webhook

```json
{
  "metadata": { "type": "Webhook" },
  "name": "my-webhook",
  "webhook": {
    "url": "https://example.com/webhook",
    "headers": { "Authorization": "Bearer {{ TOKEN }}" },
    "query": "subscription { schemaJobAllocations(operation: [UPDATE]) { data { UID } } }",
    "type": "graphql"
  }
}
```

### Triggered Action

```json
{
  "metadata": { "type": "TriggeredAction" },
  "name": "my-triggered-action",
  "enabled": true,
  "trigger": {
    "type": "object_modified",
    "filter": "Operation == 'INSERT'",
    "schemaName": "JobAllocations"
  },
  "action": {
    "type": "call_url",
    "url": "https://api.skedulo.com/function/func/func/myFunction",
    "headers": { "Authorization": "Bearer {{ API_TOKEN }}" },
    "query": "{ JobId ResourceId }"
  }
}
```

### Horizon Page

```json
{
  "metadata": { "type": "HorizonPage" },
  "name": "My Page",
  "templateName": "my-template",
  "slug": "my-page",
  "published": true,
  "pageType": "CUSTOM"
}
```

### Horizon Template (Bundled)

```json
{
  "metadata": { "type": "HorizonTemplate" },
  "name": "my-template",
  "description": "",
  "kind": "PAGE_EXTENDED",
  "source": "./my-template"
}
```

### Web Extension (Bundled)

```json
{
  "metadata": { "type": "WebExtension" },
  "name": "my-extension",
  "source": "./my-extension"
}
```

### Public Page (Bundled)

```json
{
  "metadata": { "type": "PublicPage" },
  "name": "my-page",
  "source": "./my-page"
}
```

### User Role

```json
{
  "metadata": { "type": "UserRole" },
  "name": "Custom Role",
  "description": "Role description",
  "custom": true,
  "permissionPatterns": [
    "skedulo.tenant.web.access",
    "skedulo.tenant.data.view",
    "skedulo.tenant.data.modify"
  ]
}
```

Permission patterns support wildcards: `skedulo.tenant.attachments.*`

### Example Artifacts

See https://github.com/skeduloDevelopers/SkeduloCLIExamples for complete examples of every artifact type.
