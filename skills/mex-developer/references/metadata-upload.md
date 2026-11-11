# MEX Metadata & Upload Configuration Reference

These files define how the form is deployed and how it behaves within the Skedulo Plus mobile app.

## Project Structure

A MEX project MUST follow this structure:
- `upload_config.json` (Root)
- `<defId>.mobile-extension.json` (package descriptor — in the form folder or its parent, see below)
- `mex_definition/` (Folder)
    - `metadata.json`
    - `instanceFetch.json`
    - `staticFetch.json`
    - `ui_def.json`
    - `static_resources/locales/en.json`

The plugin's `PostToolUse` hook (`scripts/validate_mex_form.py`) enforces the `defId`, `engineVersion`,
descriptor, `contextObject` and `contextObjectFields` rules below on every Write/Edit of these files; an
already-deployed legacy `defId` goes in `src/mobile-extensions/naming-exceptions.json` (`{"names": [...]}`).
The missing-descriptor check runs only from the command line (explicit paths or `--workspace`), not in the
hook, because the hook sees `upload_config.json` before the descriptor exists.

---

## `upload_config.json`

Located at the **project root**. This file contains basic configuration for uploading and identifying the form.

**Properties:**
- **`name`**: The display label shown to users in the Skedulo Plus app.
- **`defId`**: A unique identifier for the form within the tenant. **MUST use snake_case (underscores) instead of hyphens.** (e.g., `job_completion_v1`).
- **`engineVersion`**: The minimum version of the MEX Engine required. Use `"1.0.0"`. Tenants have rejected other values seen so far (e.g. `"1.1.0"`) on upsert; change it only when the target tenant is known to accept a newer one.
- **`customFunctionFeatures`**: (Skip for now) Flags for custom fetch/save functions.
  ```json
  {
    "customFunctionFeatures": {
      "fetchFunction": false,
      "saveFunction": false
    }
  }
  ```

---

## `<defId>.mobile-extension.json`

Package descriptor. `sked package` discovers the form through it; without one the form is not packaged.
The registry recognises a descriptor by its content (`metadata.type: "MobileExtension"`), not its filename,
but `<defId>.mobile-extension.json` is the convention. `source` is resolved relative to the descriptor's own
folder and must point at the form folder (the one holding `upload_config.json`). Keep `defId` identical to
`upload_config.json`.

Two layouts are valid:

```text
src/mobile-extensions/                     # layout written by `sked artifacts mobile-extension get`
├── job_completion_v1.mobile-extension.json   # "source": "./job_completion_v1"
└── job_completion_v1/
    ├── upload_config.json
    └── mex_definition/

job_completion_v1/                         # descriptor inside the form folder
├── job_completion_v1.mobile-extension.json   # "source": "."
├── upload_config.json
└── mex_definition/
```

```json
{
  "metadata": { "type": "MobileExtension" },
  "defId": "job_completion_v1",
  "source": "./job_completion_v1"
}
```

- **`metadata.type`**: Always `"MobileExtension"`.
- **`defId`**: Same value as `upload_config.json`.
- **`source`**: The form folder, relative to the descriptor — `"./<defId>"` from the parent folder, `"."` from inside the form folder.

---

## `metadata.json`

Located in `mex_definition/`. This file contains characteristics and rules for the form extension.

**Properties:**
- **`summary`**: Plain text string shown as the subtitle in the app's form list. **This is NOT a localized key** — it does not reference `en.json`. Write a short, meaningful description of what the form does directly as the value (e.g., `"Record safety inspection results"`, `"Complete post-job survey"`). Do NOT use generic text like `"Form Summary"` or `"Fill out form"`.
- **`email`**: Administrator's email for notifications.
- **`contextObject`**: **CRITICAL**: Defines where the form is linked in the mobile app. **ONLY 3 valid values**:
  - `"Jobs"`: Form is linked to a Job (appears in Job details screen).
  - `"Shifts"`: Form is linked to a Shift (appears in Shift details screen).
  - `"Resources"`: **Global form** displayed in the "More" menu (not linked to a specific Job or Shift).
  - **NOTE**: `contextObject` is NOT the object you fetch data from—it's where the form appears in the app. **If unclear from requirements, ask the user explicitly.**
- **`contextObjectFields`**: (Advanced) Defines fields used for expression evaluation. **Only include this field when it has at least one entry. Do NOT define it as an empty array — omit it entirely if unused.**
- **`displayOrder`**: Numeric value for vertical positioning (lower is higher).
- **`showIf`**: (Expression) Boolean expression determining if the form is visible to the user.
- **`mandatoryIf`**: (Expression) Boolean expression determining if the form is marked as mandatory (asterisk next to name).
- **`mandatoryExpression`**: (Expression) Determines if the form is considered "complete".
- **`references`**: Maps fetched object names to their relationship/lookup field names that the MEX engine should preserve. **Only required when the form allows the user to edit an existing record's relationship field** Format: `{ "ObjectName": ["RelationshipFieldName", ...] }`.

### Example: metadata.json

```json
{
  "summary": "Record safety inspection results for a job",
  "email": "admin@skedulo.com",
  "contextObject": "Jobs",
  "revision": 1,
  "displayOrder": 10,
  "showIf": "it.Type == 'Installation'",
  "mandatoryIf": "it.Status == 'In Progress'",
  "references": {
    "JobAllocations": ["Resource"]
  }
}
```
*(Note: `it` refers to the context object, e.g., the Job object. `summary` is plain text displayed directly — it is not a localized key.)*
