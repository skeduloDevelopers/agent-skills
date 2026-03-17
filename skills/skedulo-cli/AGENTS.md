# skedulo-cli

Safe, effective usage of the Skedulo CLI (`sked`) on the Pulse Platform.

## Use this skill when

- Running any `sked` command
- Deploying packages or artifacts to a Pulse tenant
- Switching between tenants or checking tenant auth status
- Inspecting platform artifacts (functions, webhooks, custom objects, horizon pages, etc.)
- Modifying or upserting platform artifacts
- Debugging CLI errors or auth failures
- Performing destructive operations (delete, package register)

## What to expect

Once activated, this skill enforces alias (`-a`) usage on every tenant-scoped command, proactively uses `--help` to confirm flag support, guides safe inspection patterns (`--json`, `list` for discovery), and requires confirmation before destructive operations. It prevents common mistakes like deploying to the wrong tenant, using the wrong artifact identifiers, or accidentally downloading files when only inspection is needed.

## Example

    # Inspect a function artifact safely
    sked artifacts function get --name MyFunction --json -a <alias>
