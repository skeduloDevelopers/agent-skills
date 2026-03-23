# Skedulo CLI

Safe, effective usage of the Skedulo CLI (`sked`) on the Pulse Platform.

## Use this skill when

- Running any `sked` command
- Deploying packages or artifacts to a Pulse tenant
- Switching between tenants or checking tenant auth status
- Inspecting or modifying platform artifacts (functions, webhooks, custom fields, horizon pages, etc.)
- Debugging CLI errors or auth failures
- Performing destructive operations (delete, package register)

## Key rules

- Every tenant-scoped command MUST include `-a <alias>`
- Always run `--help` before guessing flags
- Clone `SkeduloCLIExamples` repo for artifact JSON schemas — never guess
- Use `list --json` for discovery, `get --json` for inspection
- Confirm with user before any destructive operation

## Examples

    # Inspect an artifact
    sked artifacts function list --json -a my-tenant

    # Create a custom field (get schema from examples repo first)
    sked artifacts custom-field upsert -f MyField.custom-field.json -a my-tenant

    # Deploy a package
    sked package deploy local -p ./my-package -a my-tenant --dryRun
