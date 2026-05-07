# MEX Flat Page - Steps Mode Examples

Steps Mode allows a single `flat` page to be divided into multiple sequential or conditional steps. This is ideal for long forms or wizard-like experiences.

## Basic Sequential Steps Example

In this example, the user moves through three steps: "Initial Info", "Details", and "Summary". It also demonstrates **`stepRecognizedOnInitCondition`** to resume a specific step if data already exists.

### `ui_def.json` (Root)

```json
{
  "firstPage": "JobCompletionPage",
  "pages": {
    "JobCompletionPage": {
      "type": "flat",
      "mode": "steps",
      "title": "PageTitle",
      "stepDef": {
        "stepValue": "pageData.__currentStep",
        "prevButtonText": "PrevBtn",
        "nextButtonText": "NextBtn",
        "submitButtonText": "SubmitBtn",
        "steps": [
          {
            "key": "step1",
            "stepRecognizedOnInitCondition": "formData.Job.Name == null",
            "ui": {
              "items": [
                {
                  "type": "textEditor",
                  "title": "NameTitle",
                  "valueExpression": "formData.Job.Name"
                }
              ]
            }
          },
          {
            "key": "step2",
            "stepRecognizedOnInitCondition": "formData.Job.Name != null && formData.Job.CompletionDate == null",
            "ui": {
              "items": [
                {
                  "type": "dateTimeEditor",
                  "title": "DateTitle",
                  "mode": "date",
                  "valueExpression": "formData.Job.CompletionDate"
                }
              ]
            }
          },
          {
            "key": "step3",
            "stepRecognizedOnInitCondition": "formData.Job.CompletionDate != null",
            "ui": {
              "items": [
                {
                  "type": "readonlyTextView",
                  "title": "ReviewTitle",
                  "text": "ReviewBody"
                }
              ]
            }
          }
        ]
      }
    }
  }
}
```

### `en.json` (Locales)

```json
{
  "PageTitle": "Complete Job",
  "PrevBtn": "Back",
  "NextBtn": "Continue",
  "SubmitBtn": "Finish",
  "NameTitle": "Job Name",
  "DateTitle": "Completion Date",
  "ReviewTitle": "Review Information",
  "ReviewBody": "Please review your entries before submitting: ${formData.Job.Name} on ${formData.Job.CompletionDate}"
}
```

---

## Conditional Step Routing Example

This example demonstrates how to skip a step based on user input. If the user selects "Internal" as the job type, they skip the "Customer Satisfaction" step.

### `ui_def.json` (Snippet)

```json
{
  "type": "flat",
  "mode": "steps",
  "stepDef": {
    "stepValue": "pageData.stepIdx",
    "steps": [
      {
        "key": "jobTypeStep",
        "ui": {
          "items": [
            {
              "type": "selectEditor",
              "title": "TypeTitle",
              "valueExpression": "pageData.tempType",
              "sourceExpression": "sharedData.JobTypes"
            }
          ]
        },
        "nextStepRoutingLogic": [
          {
            "condition": "pageData.tempType == 'Internal'",
            "key": "summaryStep"
          },
          {
            "key": "customerStep"
          }
        ]
      },
      {
        "key": "customerStep",
        "ui": {
          "items": [
            {
              "type": "textEditor",
              "title": "FeedbackTitle",
              "valueExpression": "formData.Job.Feedback"
            }
          ]
        }
      },
      {
        "key": "summaryStep",
        "ui": {
          "items": [
            {
              "type": "messageBox",
              "theme": "success",
              "title": "ReadyTitle",
              "text": "ReadyBody"
            }
          ]
        }
      }
    ]
  }
}
```

---

## Data Binding & Initialization

- **`stepValue`**: This is usually bound to a `pageData` variable. It tracks the `key` of the current step.
- **`stepRecognizedOnInitCondition`**: Expression evaluated when the page is loaded. The first step whose condition returns `true` becomes the active step.

```json
{
  "key": "editStep",
  "stepRecognizedOnInitCondition": "formData.Job.Status == 'In Progress'",
  "ui": { "items": [] }
}
```

## Key Guidelines for Claude Code

1.  **Page Level**: Steps Mode is configured at the top level of a `flat` page definition.
2.  **No Children**: When `mode: "steps"` is used, the page MUST NOT have a `children` array; instead, it uses `stepDef`.
3.  **Local Navigation**: `nextStepRoutingLogic` within a step determines the next step *within the same page*. Use the **`key`** property to target the next step.
4.  **Data Context**: `sourceExpression` for selectors should point to a data context (e.g., `sharedData.Options`) rather than a hardcoded array.
5.  **Localization**: All button text (`prevButtonText`, etc.) and UI labels inside steps must use pure string keys from `en.json`.
