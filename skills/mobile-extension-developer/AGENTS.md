# mobile-extension-developer

Build, modify, and validate Skedulo Mobile Extensions (MEX) for the Skedulo Plus mobile app.

## Use this skill when

- Creating a new Mobile Extension form (MEX)
- Modifying an existing MEX form's UI, data, or routing
- Adding multi-step flows or conditional steps to a form (Steps Mode)
- Defining instance or static data fetches via the MEX GraphQL JSON format
- Working with localization (`en.json`), expressions, or data binding contexts (`formData`, `sharedData`, `pageData`, `it`, `item`)
- Configuring `metadata.json` for context object, visibility, or mandatory rules
- Reviewing or debugging MEX form structure, JSON shape, or expression syntax

## What to expect

Once activated, this skill guides correct MEX project structure (`upload_config.json`, `mex_definition/`), UI component selection, GraphQL data-fetching JSON, localization patterns, expression syntax, and multi-step form design. It enforces the localized-key pattern (pure string keys in `ui_def.json`, content in `locales/en.json`) and the `pageData` editing pattern for list-to-detail flows.

## Example

    {
      "type": "textEditor",
      "title": "JobNameLabel",
      "valueExpression": "formData.JobDetails.Name",
      "showIfExpression": "formData.JobDetails.Status != 'Complete'"
    }
