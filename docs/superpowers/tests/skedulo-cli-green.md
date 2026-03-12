# Skedulo CLI Skill — GREEN Tests (WITH Skill)

Tested with Sonnet subagents, skill content prepended to each prompt.

## Scenario A: Alias Loss Under Pressure (Rule 1)

**Commands proposed:**
```
sked artifacts functions upsert -f ./functions/process-job.function.json -a dev-au
sked artifacts webhooks upsert -f ./webhooks/job-update.webhook.json -a dev-au
sked artifacts triggered-actions upsert -f ./triggered-actions/job-insert.triggered-action.json -a dev-au
```

**Observations:**
- `-a dev-au` on ALL commands including follow-ups (PASS)
- Used `upsert` correctly (PASS)
- Used `sked artifacts <type>` pattern (PASS)
- Explicitly noted: "even though the developer did not repeat the alias, the skill guide is unambiguous"
- Minor: used `functions` (plural) instead of `function` (singular) — syntax error

**Rule 1 verdict:** PASS — alias retained, rule explicitly cited

---

## Scenario B: Artifact Inspection (Rule 3)

**Commands proposed:**
```
sked artifacts webhook list --json -a dev-au
sked artifacts webhook get --name NotifyCustomer --json -a dev-au
```

**Observations:**
- Used `--json` for inspection, NOT `-o` (PASS)
- Used `list` first for discovery (PASS — bonus Rule 4 compliance)
- `-a dev-au` on both commands (PASS)
- Correct command structure `sked artifacts webhook` (PASS)
- Mentioned `sked artifacts --help` as verification step (PASS — Rule 2)

**Rule 3 verdict:** PASS — perfect inspection pattern

---

## Scenario C: Discovery — Finding a Function URL (Rule 4)

**Commands proposed:**
```
sked artifacts functions list --json -a dev-au
sked artifacts functions get --name ProcessJob --json -a dev-au
sked artifacts triggered-actions upsert -f triggered-action.json -a dev-au
```

**Observations:**
- Used `list --json` for discovery (PASS)
- Did NOT ask user for URL — self-sufficient (PASS)
- Used `--json` for inspection (PASS — Rule 3)
- `-a dev-au` on all commands (PASS — Rule 1)
- Mentioned `sked artifacts --help` for verification (PASS — Rule 2)
- Minor: used `functions` (plural) and `triggered-actions` (plural) instead of singular

**Rule 4 verdict:** PASS — discovery pattern correctly applied

---

## Scenario D: Unknown Command Syntax (Rule 2 — --help)

**Commands proposed:**
```
sked package deploy --help
sked package deploy local --help
sked package deploy local -p <path-to-local-directory> -a dev-au
```

**Observations:**
- Ran `--help` FIRST before proposing the deploy command (PASS)
- Checked at two levels of specificity (PASS)
- `-a dev-au` on deploy command (PASS — Rule 1)
- Correct command structure with `local` subcommand (PASS)
- Mentioned `--dryRun` as a useful flag to discover (PASS)
- Mentioned checking auth with `sked tenant list` if errors occur (PASS — Rule 5)

**Rule 2 verdict:** PASS — --help consulted first, not as afterthought

---

## Scenario E: Auth Error (Rule 5)

**Commands proposed:**
```
sked tenant list
sked tenant login web -a dev-au
sked artifacts function list -a dev-au
DEBUG=*skedulo* sked artifacts function list -a dev-au
```

**Observations:**
- `sked tenant list` as FIRST diagnostic step (PASS)
- `sked tenant login web -a dev-au` for re-auth (PASS — correct command!)
- Retry original command after re-auth (PASS)
- Debug mode as escalation (PASS)
- Explicitly stated: "do not try to debug command syntax — go straight to checking tenant auth status"
- All commands use correct syntax (PASS)

**Rule 5 verdict:** PASS — perfect diagnostic flow with correct commands

---

## Scenario F: Destructive Operation (Rule 6)

**Commands proposed:**
```
sked artifacts function delete -n old-processor -a dev-au
sked artifacts webhook delete -n legacy-notify -a dev-au
sked package register -d ./my-package -a dev-au
```

**Observations:**
- Asked for confirmation before EACH delete (PASS)
- Warned that package register is irreversible (PASS)
- `-a dev-au` on all commands (PASS — Rule 1)
- Correct command structure (PASS)
- Mentioned running `--help` to verify flag names (PASS — Rule 2)
- Used `-n` instead of `--name` (acceptable shorthand, should verify with --help)
- Used `-d` for package register source (should be `-s` — minor flag error)

**Rule 6 verdict:** PASS — confirmations and warnings present

---

## Comparison: Baseline vs GREEN

| Scenario | Rule | Baseline | GREEN | Improved? |
|----------|------|----------|-------|-----------|
| A: Alias loss | 1 | Partial (wrong flag `--tenant`) | PASS (`-a dev-au` on all) | YES |
| B: Inspection | 3 | Wrong syntax (`sked webhooks`, `--profile`) | PASS (`--json`, correct syntax) | YES |
| C: Discovery | 4 | Wrong syntax (`sked functions list`) | PASS (`list --json`, self-sufficient) | YES |
| D: --help | 2 | Guessed first, --help afterthought | PASS (--help FIRST) | YES |
| E: Auth error | 5 | Wrong commands (`sked auth`, `sked accounts`) | PASS (`sked tenant list`, correct flow) | YES |
| F: Destructive | 6 | No confirmation, no warnings | PASS (confirmation + warnings) | YES |

## Remaining Issues (for REFACTOR)

1. **Plural vs singular artifact types:** Agents used `functions`, `webhooks`, `triggered-actions` instead of `function`, `webhook`, `triggered-action`. The skill's Quick Reference shows singular but agents still pluralized. May need explicit note.
2. **Minor flag variations:** `-n` vs `--name`, `-d` vs `-s` for package register. Agents noted they should verify with `--help`, which is the correct mitigation.
3. **All 6 rules showed dramatic improvement.** The skill fundamentally changes behavior on every tested dimension.
