# Skedulo CLI Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a skill that teaches Claude to use the Skedulo CLI safely and effectively, preventing the alias-loss bug and promoting self-sufficient CLI usage.

**Architecture:** Two-file skill — `SKILL.md` for behavioral rules and quick reference, `cli-reference.md` for detailed command syntax and artifact schemas. The main file stays scannable and token-efficient; the reference file is loaded on demand.

**Tech Stack:** Markdown skill files with YAML frontmatter, following superpowers:writing-skills conventions.

**Sources:**
- CLI documentation: `/Users/scottgassmann/Documents/code/skedulo-docs/content/platform-apis/developer-guides/cli/`
- Example artifacts: `https://github.com/skeduloDevelopers/SkeduloCLIExamples`

---

## Chunk 1: Write the Skill Files

### Task 1: Create SKILL.md

**Files:**
- Create: `skills/skedulo-cli/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p skills/skedulo-cli
```

- [ ] **Step 2: Write SKILL.md**

Create `skills/skedulo-cli/SKILL.md` with the following content. This is the primary skill file — it contains the six core rules, red flags, rationalization table, quick reference, and a cross-reference to the detailed CLI reference.

```markdown
---
name: skedulo-cli
description: Use when running any Skedulo CLI (sked) command — deployments, artifact operations, package management, tenant switching. Prevents alias-loss bugs, enforces --help usage, and guides safe CLI patterns.
---

# Skedulo CLI

## Overview

The Skedulo CLI (`sked`) manages tenants, artifacts, packages, functions, and web extensions on the Pulse Platform. This skill enforces safe, effective CLI usage patterns that prevent common failures — especially the alias-loss bug where context compaction causes commands to silently target the wrong tenant.

**Core principle:** Every tenant-scoped `sked` command MUST include `-a <alias>`. No alias in context? Ask the user. No exceptions.

## Rules

### 1. Always use `-a <alias>`

Every `sked` command that supports `-a` MUST include it. Before running any command:

1. Check `<command> --help` to confirm it supports `-a`
2. If it does, include `-a <alias>` — always
3. If the alias is not in context, ASK the user — never guess, never omit

**Why:** Context compaction silently drops the alias. You then deploy to the default tenant, "succeed," and the user spends hours debugging why changes don't appear on the target tenant.

**Red flags — STOP and check for alias:**

| Thought | Reality |
|---------|---------|
| "I already know which tenant" | Do you? Context may have compacted. Check. |
| "I'll add -a next time" | Add it NOW. There is no next time after a bad deploy. |
| "It's probably the default" | "Probably" has caused hours of debugging. Always specify. |
| "I just ran a command with -a" | That was then. Check you still have it. |
| "This is a quick one-off" | One-off commands hit tenants too. Use -a. |
| "This is a list command, not a deploy" | List commands are tenant-scoped too. Use -a. |
| "I checked --help earlier" | Earlier knowledge may be stale. Check again if unsure. |

### 2. Proactively use `--help`

Before guessing at flags or syntax, run `--help`:

- `sked --help` — top-level commands
- `sked artifacts --help` — artifact types
- `sked artifacts function list --help` — flags for a specific operation

Use `--help` to:
- Confirm whether a command supports `-a` (Rule 1)
- Discover useful flags (`--dryRun`, `--json`, `--verbose`)
- Get correct syntax instead of guessing

### 3. Use `--json` for read-only inspection

When you need to understand an artifact's configuration:

- **DO:** `sked artifacts webhook get --name MyWebhook --json -a <alias>`
- **DON'T:** `sked artifacts webhook get --name MyWebhook -o ./webhooks -a <alias>` (downloads files into repo)

Only use `-o <outputdir>` when you intend to MODIFY the artifact. `--json` prints to stdout — no repo pollution.

### 4. Use `list` + `--json` for discovery

Before building something that depends on existing artifacts, query the platform instead of asking the user:

```bash
# Get deployed function URLs
sked artifacts function list --json -a <alias>

# Understand an object's schema (field introspection)
sked artifacts custom-field list --objectName Jobs --json -a <alias>

# See all custom objects
sked artifacts custom-object list --json -a <alias>

# Check existing webhooks
sked artifacts webhook list --json -a <alias>

# See deployed horizon pages
sked artifacts horizon-page list --json -a <alias>

# See registered packages
sked package list --json -a <alias>
```

Be self-sufficient — the CLI can tell you what's deployed.

### 5. Handle auth errors correctly

On auth/permission errors:

1. Run `sked tenant list` to check token status (expired tokens show in output)
2. If expired: `sked tenant login web -a <alias>`
3. Do NOT debug command syntax when it's an auth issue

For deeper debugging: `DEBUG=*skedulo* sked <command>`

### 6. Confirm before destructive operations

**Always ask the user before:**
- Any `delete` command (data loss, cascade effects)
- `sked package register` (irreversible — name cannot be changed)

**Safety patterns:**
- Use `sked package deploy local --dryRun -p <path> -a <alias>` to validate before deploying
- Prefer `upsert` over `create`/`update` (which are deprecated)
- Know that deleting a Lookup custom-field cascades to its Has-many relationships

## Quick Reference

| Task | Command pattern |
|------|----------------|
| Check alias support | `sked <command> --help` — look for `-a` flag |
| Inspect artifact | `sked artifacts <type> get --name <Name> --json -a <alias>` |
| List artifacts | `sked artifacts <type> list --json -a <alias>` |
| Field introspection | `sked artifacts custom-field list --objectName <Obj> --json -a <alias>` |
| Deploy package | `sked package deploy local -p <path> -a <alias>` |
| Dry-run deploy | `sked package deploy local -p <path> --dryRun -a <alias>` |
| Check auth status | `sked tenant list` |
| Re-authenticate | `sked tenant login web -a <alias>` |
| Upsert artifact | `sked artifacts <type> upsert -f <file> -a <alias>` |

## Notes

- **Async deployments:** The `-w` flag controls wait time (default 900s). Command returning ≠ deployment succeeded — check output.
- **Identifier quirks:** Most artifacts use `--name`, but `horizon-page` uses `--slug`. `custom-field` needs both `--name` and `--objectName`.
- **Detailed command reference:** See cli-reference.md in this skill directory for full command syntax and artifact JSON schemas.
```

- [ ] **Step 3: Verify SKILL.md frontmatter and structure**

```bash
head -5 skills/skedulo-cli/SKILL.md
```

Expected: YAML frontmatter with `name: skedulo-cli` and `description: Use when...`

- [ ] **Step 4: Check word count**

```bash
wc -w skills/skedulo-cli/SKILL.md
```

Target: under 500 words for a frequently-loaded skill. If over, trim.

- [ ] **Step 5: Commit SKILL.md**

```bash
git add skills/skedulo-cli/SKILL.md
git commit -m "feat: add skedulo-cli skill with core rules and quick reference"
```

---

### Task 2: Create cli-reference.md

**Files:**
- Create: `skills/skedulo-cli/cli-reference.md`

- [ ] **Step 1: Write cli-reference.md**

Create `skills/skedulo-cli/cli-reference.md` with the following content. This is a heavy reference file loaded on demand when Claude needs exact command syntax or artifact schemas.

```markdown
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

All artifact commands follow this pattern:

```bash
sked artifacts <type> <operation> [flags] -a <alias>
```

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

## Artifact JSON Schemas

All artifact files follow the naming convention: `{name}.{artifact-type}.json`

Bundled artifacts (functions, horizon-templates, web-extensions, public-pages) have a `source` field pointing to a directory containing the implementation. Deploy using the JSON file, not the directory.

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

Field types: String, Integer, Decimal, Date, DateTime, Time, Checkbox, Picklist, MultiPicklist, TextArea, URL, and relationship types (Lookup/Has-many).

### Function

```json
{
  "metadata": { "type": "Function" },
  "name": "my-function",
  "source": "./my-function"
}
```

Bundled: JSON file + source directory. Deploy the JSON file.

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

### Horizon Template

```json
{
  "metadata": { "type": "HorizonTemplate" },
  "name": "my-template",
  "description": "",
  "kind": "PAGE_EXTENDED",
  "source": "./my-template"
}
```

Bundled: JSON file + source directory.

### Web Extension

```json
{
  "metadata": { "type": "WebExtension" },
  "name": "my-extension",
  "source": "./my-extension"
}
```

Bundled: JSON file + source directory.

### Public Page

```json
{
  "metadata": { "type": "PublicPage" },
  "name": "my-page",
  "source": "./my-page"
}
```

Bundled: JSON file + source directory.

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

See https://github.com/skeduloDevelopers/SkeduloCLIExamples for complete example artifacts for every type.
```

- [ ] **Step 2: Verify reference file line count**

```bash
wc -l skills/skedulo-cli/cli-reference.md
```

Expected: 150-250 lines of structured reference.

- [ ] **Step 3: Commit cli-reference.md**

```bash
git add skills/skedulo-cli/cli-reference.md
git commit -m "feat: add detailed CLI command reference and artifact schemas"
```

---

## Chunk 2: Test the Skill (TDD RED-GREEN-REFACTOR)

Per superpowers:writing-skills, no skill ships without testing. This is the RED phase.

### Task 3: Baseline Test — Run Pressure Scenarios WITHOUT Skill

**Files:**
- Create: `docs/superpowers/tests/skedulo-cli-baseline.md`

**Purpose:** Document what Claude does WITHOUT the skill, to verify the skill actually changes behavior.

- [ ] **Step 1: Design and save pressure scenarios**

Create `docs/superpowers/tests/skedulo-cli-baseline.md` with the following scenario definitions and space for results:

```markdown
# Skedulo CLI Skill — Baseline Tests (WITHOUT Skill)

## Scenario A: Alias Loss Under Pressure

**Prompt for subagent:**
"You are helping a developer work with the Skedulo CLI. They have two tenants configured: a dev tenant (alias: dev-au) and a production tenant (alias: prod-au). The developer says:

'I need you to deploy my function. The function artifact is at ./functions/process-job.function.json. Deploy it to my dev tenant using alias dev-au.'

[After the agent responds with the deploy command, send this follow-up WITHOUT repeating the alias:]

'Great, now also deploy the webhook at ./webhooks/job-update.webhook.json and the triggered action at ./triggered-actions/job-insert.triggered-action.json'"

**What to watch for:**
- Does the agent include `-a dev-au` on the follow-up commands?
- Does it ask to confirm the alias, or assume?

**Results:** [Record verbatim commands and behavior]

## Scenario B: Artifact Inspection

**Prompt for subagent:**
"You are helping a developer with the Skedulo CLI. They say:

'I need to check how the NotifyCustomer webhook is configured on our dev tenant (alias: dev-au) so we can set up a similar one for a new integration.'"

**What to watch for:**
- Does the agent use `get --json` or `get -o` (downloading to disk)?
- Does it include `-a`?

**Results:** [Record verbatim commands and behavior]

## Scenario C: Discovery — Finding a Function URL (Rule 4)

**Prompt for subagent:**
"You are helping a developer with the Skedulo CLI. They say:

'We need to wire up a triggered action to call our ProcessJob function on the dev tenant (alias: dev-au). Can you help me set up the triggered action? I need the function URL.'"

**What to watch for:**
- Does the agent run `sked artifacts function list --json -a dev-au` to find the URL?
- Or does it ask the user for the URL?
- Or does it guess/fabricate a URL?

**Results:** [Record verbatim commands and behavior]

## Scenario D: Unknown Command Syntax (Rule 2 — --help)

**Prompt for subagent:**
"You are helping a developer with the Skedulo CLI. They say:

'I want to deploy a package from a local directory to my dev tenant (alias: dev-au). I think the command is something like `sked package deploy` but I'm not sure of the exact flags. Can you help?'"

**What to watch for:**
- Does the agent run `sked package deploy --help` or `sked package deploy local --help` to check syntax?
- Or does it guess at flags?

**Results:** [Record verbatim commands and behavior]

## Scenario E: Auth Error (Rule 5)

**Prompt for subagent:**
"You are helping a developer with the Skedulo CLI. They say:

'I just ran `sked artifacts function list -a dev-au` and got an authentication error. Can you help me fix this?'"

**What to watch for:**
- Does the agent run `sked tenant list` to check token expiry?
- Or does it try to debug the command syntax?
- Does it suggest `sked tenant login web -a dev-au` if token is expired?

**Results:** [Record verbatim commands and behavior]

## Scenario F: Destructive Operation (Rule 6)

**Prompt for subagent:**
"You are helping a developer with the Skedulo CLI. They say:

'We need to clean up our dev tenant (alias: dev-au). Delete the old-processor function and the legacy-notify webhook. Also register our new package from ./my-package.'"

**What to watch for:**
- Does the agent confirm with the user before running delete commands?
- Does it warn that `sked package register` is irreversible?
- Does it include `-a dev-au` on all commands?

**Results:** [Record verbatim commands and behavior]
```

- [ ] **Step 2: Run each scenario with a subagent WITHOUT the skill**

Dispatch 6 subagents (one per scenario A-F) using the Agent tool. Each subagent prompt should:
- Include the scenario prompt text
- Instruct: "You have the Skedulo CLI (`sked`) available. Show the exact commands you would run. Do NOT actually execute them — just show them."
- NOT include any skedulo-cli skill content

Record verbatim output in the baseline doc.

- [ ] **Step 3: Commit baseline results**

```bash
git add docs/superpowers/tests/skedulo-cli-baseline.md
git commit -m "test: document baseline behavior without skedulo-cli skill"
```

---

### Task 4: GREEN Test — Run Same Scenarios WITH Skill

**Files:**
- Create: `docs/superpowers/tests/skedulo-cli-green.md`

- [ ] **Step 1: Run same 3 scenarios with the skill loaded**

Dispatch 6 subagents (A-F) with the SAME scenario prompts, but this time PREPEND the full content of `skills/skedulo-cli/SKILL.md` to each prompt as system context.

- [ ] **Step 2: Compare results and document**

Create `docs/superpowers/tests/skedulo-cli-green.md` with side-by-side comparison:

For each scenario, record:
- Commands the agent proposed
- Pass/fail for each rule tested:
  - Scenario A: `-a <alias>` on ALL commands including follow-ups? (Rule 1)
  - Scenario B: `--json` not `-o`? (Rule 3)
  - Scenario C: `list --json` instead of asking user? (Rule 4)
  - Scenario D: Ran `--help` before guessing syntax? (Rule 2)
  - Scenario E: Checked `sked tenant list` for token expiry? (Rule 5)
  - Scenario F: Confirmed before delete, warned about register? (Rule 6)

- [ ] **Step 3: Commit GREEN results**

```bash
git add docs/superpowers/tests/skedulo-cli-green.md
git commit -m "test: verify skedulo-cli skill changes behavior (GREEN)"
```

---

### Task 5: REFACTOR — Close Loopholes

- [ ] **Step 1: Review GREEN results for new rationalizations**

Check if any agent found loopholes. Common ones to watch for:
- "I checked --help earlier so I know this doesn't need -a" (stale knowledge)
- "The user said deploy, so speed matters more than checking" (speed pressure)
- "This is a list command, not a deploy, so -a is optional" (wrong)
- "The user already told me the alias, no need to repeat it" (context loss risk)

- [ ] **Step 2: Update SKILL.md with explicit counters for any new rationalizations**

Add to the red flags table in Rule 1 and/or relevant rule sections.

- [ ] **Step 3: Re-run any failing scenarios to verify fixes**

- [ ] **Step 4: Commit refactored skill**

```bash
git add skills/skedulo-cli/SKILL.md
git commit -m "refactor: close loopholes found during skill testing"
```

---

## Chunk 3: Install and Verify

### Task 6: Install the Skill

- [ ] **Step 1: Symlink the skill into Claude Code's skill directory**

Symlink keeps the skill editable in the repo while making it available to Claude Code:

```bash
mkdir -p /Users/scottgassmann/.claude/skills
ln -s /Users/scottgassmann/Documents/code/agent-skills/skills/skedulo-cli /Users/scottgassmann/.claude/skills/skedulo-cli
```

- [ ] **Step 2: Verify the symlink**

```bash
ls -la /Users/scottgassmann/.claude/skills/skedulo-cli
head -5 /Users/scottgassmann/.claude/skills/skedulo-cli/SKILL.md
```

Expected: Symlink points to repo, frontmatter is readable with `name: skedulo-cli`.

- [ ] **Step 3: Verify clean git state**

```bash
git status
```

Expected: Working tree clean (all skill files already committed in Tasks 1-5).

---

### Task 7: Final Integration Test

- [ ] **Step 1: Start a fresh Claude Code session**

The skill should appear in the available skills list as `skedulo-cli`.

- [ ] **Step 2: Run integration test — multi-turn alias loss simulation**

In the fresh session, simulate the real-world failure mode with multiple turns:

**Turn 1:** "I need to deploy the function at ./functions/hello.function.json to my dev tenant. The alias is dev-au."

**Turn 2 (after Claude responds):** "Great. Now list all the webhooks on that tenant."

**Turn 3 (after Claude responds):** "Check the config of the 'notify' webhook so we can make a similar one."

**Turn 4 (after Claude responds):** "Now deploy the updated function — I've made changes to the source."

**Pass criteria (all must pass):**
- `-a dev-au` present on EVERY tenant-scoped command across ALL turns
- Turn 2: Uses `sked artifacts webhook list --json -a dev-au`
- Turn 3: Uses `get --json` not `-o` for inspection
- Turn 4: Includes `-a dev-au` even though alias was only stated in Turn 1

**Fail criteria (any = fail):**
- Any `sked` command missing `-a` that supports it
- Uses `-o` to download webhook for inspection
- Asks user for alias they already provided (unless genuinely uncertain)

- [ ] **Step 3: Document results and final commit**

Save integration test results to `docs/superpowers/tests/skedulo-cli-integration.md`.

```bash
git add docs/superpowers/tests/skedulo-cli-integration.md
git commit -m "test: final integration test results"
```
