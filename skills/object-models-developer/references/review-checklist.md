# Object Models Review Checklist

The single checklist for reviewing object-model artifacts — used by the build agent's review
phase and `/object-models:review`.

Two deterministic gates own what they can prove, so don't re-derive either:
`scripts/validate_object_models.py` for per-file structure, and `scripts/validate_relationships.py`
for the workspace-local relational rules (a custom object's paired `Name`, and HasMany bindings whose
target is in this workspace). Both run at review **and** at deploy, so don't re-verify their findings by eye.

Everything below is what neither can decide — it needs SPEC.md, or tenant context via MCP. In
particular: whether a Lookup target that is **not** in this workspace actually exists on the tenant,
and whether the deploy order is right given what the tenant already has.

## Modelling

- Standard-object reuse was considered: every requirement entity was checked against
  `references/standard-objects.md`, and each custom object has a one-line justification in
  SPEC.md for why no standard object covers it
- Each paired `<Object>-Name.custom-field.json` is well-shaped: String, `required: true`,
  `unique: false`, sensible `maxLength`, non-blank default. (That the file *exists* at all is
  proven by `validate_relationships.py` — judge its contents, don't re-check its presence.)
- No custom field on a standard object shadows a known platform field (`Jobs.Start`,
  `Jobs.End`, `Accounts.Name`, audit fields, `UID`, …) — if unsure, flag for human verification
  rather than blocking

## Relationships

- Every Lookup `relationship.targetObjectName` resolves: a workspace custom object, a standard
  object, or present on the tenant via `__type` introspection (`references/tenant-auth.md`) —
  remember `--dryRun` passes dangling targets
- HasMany bindings whose child is **outside** this workspace resolve to a real Lookup on that
  child pointing back at THIS parent — `validate_relationships.py` already proves the in-workspace
  ones, but a child that lives only on the tenant needs `__type` introspection
- Multiple HasMany to the same child use distinct `targetObjectIdFieldName`s
- A deploy-order plan for relationships exists in SPEC.md: parent object → child object → child
  Lookup → parent HasMany
- No circular required-Lookup pairs (insert deadlock)

## Display & round-trip

- `showIf` expressions reference fields that exist on the same parent object
- State files retrieved from existing standard-object picklists kept
  `field.type: "StandardPicklist"` (not coerced to `Picklist`)

## Consistency & handoff

- Every SPEC.md feature marked `[x]` has a matching file on disk, and every file on disk maps to
  a feature (no orphans); field types in JSON match the SPEC descriptions
- Post-deploy admin steps are planned for new custom objects: permission-set object/field access
  and (if the tenant uses RAP) a Record Access Policy rule — noted in SPEC.md or the handoff
- Skedulo-for-Salesforce workspaces (`force-app/` present): registration steps documented per
  environment instead of Pulse deploy artifacts
