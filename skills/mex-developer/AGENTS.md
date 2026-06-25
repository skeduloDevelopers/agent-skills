# Skedulo Mobile Extensions (MEX)

Build, modify, and validate Mobile Extensions (MEX) for the Skedulo Plus app — JSON-configured mobile forms with integrated data fetching and logic.

## Use this skill when

- Building or editing a MEX form (`ui_def.json`, `instanceFetch.json`, `staticFetch.json`, `metadata.json`)
- Defining form UI pages/components, data fetching, or validation rules
- Setting form placement and visibility via `metadata.json` (`contextObject`, `showIf`)
- Localizing form text via `en.json`
- Validating a form definition before upload

## Key rules

- Follow the required project structure (`upload_config.json`, `mex_definition/`, optional `functions/`)
- All user-facing text uses localized keys from `en.json` — pure strings, no `${...}` wrapping
- `mandatory` is UI-only (asterisk) — pair it with a `validator` to actually enforce
- Data contexts: `formData` (instanceFetch), `sharedData` (staticFetch), `pageData` (selected list item)
- For server-side logic, use `mex-custom-function-builder`; for WebView forms, use `mexwex-developer`

## Example

```json
// metadata.json — attach this form to Jobs, show only when complete
{
  "contextObject": "Jobs",
  "showIf": "it.Status == 'Complete'"
}
```
