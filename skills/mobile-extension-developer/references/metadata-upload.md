# MEX Metadata & Upload Configuration Reference

These files define how the form is deployed and how it behaves within the Skedulo Plus mobile app.

## Project Structure

A MEX project MUST follow this structure:
- `upload_config.json` (Root)
- `mex_definition/` (Folder)
    - `metadata.json`
    - `instanceFetch.json`
    - `staticFetch.json`
    - `ui_def.json`
    - `static_resources/locales/en.json`

---

## `upload_config.json`

Located at the **project root**. This file contains basic configuration for uploading and identifying the form.

**Properties:**
- **`name`**: The display label shown to users in the Skedulo Plus app.
- **`defId`**: A unique identifier for the form within the tenant. **MUST use snake_case (underscores) instead of hyphens.** (e.g., `job_completion_v1`).
- **`engineVersion`**: The minimum version of the MEX Engine required (e.g., `"1.1.0"`).
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

## `metadata.json`

Located in `mex_definition/`. This file contains characteristics and rules for the form extension.

**Properties:**
- **`summary`**: A brief description shown as the second line in the app's form list (Localized Key).
- **`email`**: Administrator's email for notifications.
- **`contextObject`**: Defines where the form is displayed.
  - `"Jobs"`: Displayed in the Job details area.
  - `"Resources"`: Displayed in the "More" menu for the resource.
- **`contextObjectFields`**: (Advanced) Defines fields used for expression evaluation.
- **`displayOrder`**: Numeric value for vertical positioning (lower is higher).
- **`showIf`**: (Expression) Boolean expression determining if the form is visible to the user.
- **`mandatoryIf`**: (Expression) Boolean expression determining if the form is marked as mandatory (asterisk next to name).
- **`mandatoryExpression`**: (Expression) Determines if the form is considered "complete".

### Example: metadata.json

```json
{
  "summary": "FormSummary",
  "email": "admin@example.com",
  "contextObject": "Jobs",
  "revision": 1,
  "displayOrder": 10,
  "showIf": "it.Type == 'Installation'",
  "mandatoryIf": "it.Status == 'In Progress'"
}
```
*(Note: `it` refers to the context object, e.g., the Job object. `FormSummary` is a localized key)*
