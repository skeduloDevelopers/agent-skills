# MEX Data Fetching Reference

MEX uses `instanceFetch.json` and `staticFetch.json` to define data requirements.

## Overview

- **`instanceFetch.json`**: Fetches data specific to the form instance (e.g., details of the current Job). This data is stored in the `formData` context.
- **`staticFetch.json`**: Fetches data that is shared across forms of the same type (e.g., a list of all Products). This data is stored in the **`sharedData`** context.

## JSON GraphQL Format

MEX does not use standard GraphQL strings but a JSON-based representation.

```json
{
  "type": "GraphQl",
  "QueryResultKey": {
    "object": "ObjectName",
    "fields": [
      "Field1",
      "Field2",
      "Relationship.Field3"
    ],
    "filter": "Field1 == '${varName}'",
    "variables": {
      "varName": "$job.UID"
    },
    "orderBy": "Field1 ASC",
    "limit": 10
  }
}
```

### Root Properties
- **`type`**: Must always be `"GraphQl"`.
- **Siblings**: Each top-level key (except `type`) represents a separate query and will be a key in the resulting data context (`formData` or `sharedData`).

### Query Properties
- **`object`**: (Required) The name of the Skedulo object (e.g., `Jobs`, `Resources`, `JobProducts`).
- **`fields`**: (Required) An array of field names. Supports dot notation for child objects (e.g., `Product.Name`).
- **`filter`**: (Optional) A string representing the query filter. Use `${varName}` for dynamic values.
- **`variables`**: (Optional) A map of variable names used in the filter to their source values.
- **`orderBy`**: (Optional) Sort order (e.g., `Name ASC`, `CreatedDate DESC`).
- **`limit`**: (Optional) Maximum number of records to return.

## Special Variables

MEX provides several built-in variables that can be used in the `variables` block:

- **`$job.UID`**: The UID of the current Job (if the form is Job-contextual).
- **`$resource.UID`**: The UID of the current Resource (if the form is Resource-contextual).
- **`$user.UID`**: The UID of the logged-in user.

## Example: instanceFetch.json

Fetching job details and assigned products:

```json
{
  "type": "GraphQl",
  "JobDetails": {
    "object": "Jobs",
    "fields": ["UID", "Name", "Description", "Status"],
    "filter": "UID == '${jobId}'",
    "variables": {
      "jobId": "$job.UID"
    }
  },
  "AssignedProducts": {
    "object": "JobProducts",
    "fields": ["UID", "Qty", "Product.Name", "Product.UID"],
    "filter": "JobId == '${jobId}'",
    "variables": {
      "jobId": "$job.UID"
    }
  }
}
```

## Example: staticFetch.json

Fetching a global list of available products:

```json
{
  "type": "GraphQl",
  "AllProducts": {
    "object": "Products",
    "fields": ["UID", "Name", "Description"],
    "orderBy": "Name ASC"
  }
}
```
