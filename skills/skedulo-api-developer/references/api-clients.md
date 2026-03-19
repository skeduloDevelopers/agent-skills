# API Clients Reference

This file provides detailed reference information for all API clients available in Pulse Solution Services.

## Base API Client

Handles requests to any Skedulo API without a dedicated client.

### Methods

**performRequest(options)**

Execute any HTTP request to Skedulo APIs.

Parameters:
- `endpoint`: API endpoint path (string)
- `method`: HTTP method (GET, POST, PUT, DELETE)
- `body`: Request body (object)
- `headers`: Additional headers (object)

Examples:

```javascript
// GET request
const avatars = await context.baseClient.performRequest({
  endpoint: "files/avatar?user_ids=id1,id2"
});

// POST request
const response = await context.baseClient.performRequest({
  method: "POST",
  endpoint: "function/my-function/ping",
  body: { message: "Hello" }
});

// PUT request
await context.baseClient.performRequest({
  method: "PUT",
  endpoint: "custom/objects/MyObject",
  body: { data: "updated" }
});

// DELETE request
await context.baseClient.performRequest({
  method: "DELETE",
  endpoint: "custom/objects/MyObject/123"
});
```

## Metadata Client

Access schema metadata from `/metadata` endpoints.

### Methods

**fetchAllMetadata()**

Retrieve metadata for all objects in your org.

Returns: Object with schema definitions for all objects

```javascript
const metadata = await context.metadataClient.fetchAllMetadata();

// Access specific object metadata
const jobFields = metadata.Jobs.fields;
const jobRelationships = metadata.Jobs.relationships;
```

**fetchObjectMetadata(objectName)**

Retrieve metadata for a specific object.

Parameters:
- `objectName`: Name of the object (string)

Returns: Object with schema definition

```javascript
const jobMetadata = await context.metadataClient.fetchObjectMetadata('Jobs');

// Access field information
const fields = jobMetadata.fields;
const nameField = fields.find(f => f.name === 'Name');
console.log(`Field type: ${nameField.type}`);
```

## Vocabulary Client

Manage picklist values for custom fields via `/custom/vocabulary` endpoints.

### Methods

**getVocabularyItems(schemaName, fieldName)**

Fetch all vocabulary items for a picklist field.

Parameters:
- `schemaName`: Name of the schema (string)
- `fieldName`: Name of the field (string)

Returns: Array of vocabulary items

```javascript
const items = await context.vocabularyClient.getVocabularyItems('Jobs', 'JobType');

items.forEach(item => {
  console.log(`${item.value}: ${item.label} (active: ${item.active})`);
});
```

**addVocabularyItem(schemaName, fieldName, item)**

Add a new vocabulary item to a picklist field.

Parameters:
- `schemaName`: Name of the schema (string)
- `fieldName`: Name of the field (string)
- `item`: Vocabulary item object
  - `value`: Internal value (string)
  - `label`: Display label (string)
  - `active`: Whether item is active (boolean)
  - `defaultValue`: Whether this is the default (boolean)
  - `description`: Item description (string, optional)

```javascript
const newItem = await context.vocabularyClient.addVocabularyItem('Jobs', 'Priority', {
  value: "URGENT",
  label: "Urgent",
  active: true,
  defaultValue: false,
  description: "High priority urgent jobs"
});
```

**updateVocabularyItem(schemaName, fieldName, value, updates)**

Update an existing vocabulary item.

Parameters:
- `schemaName`: Name of the schema (string)
- `fieldName`: Name of the field (string)
- `value`: Current value to update (string)
- `updates`: Updated fields (object)

```javascript
await context.vocabularyClient.updateVocabularyItem('Jobs', 'Status', 'Pending', {
  label: "Awaiting Assignment",
  description: "Job is waiting for resource assignment"
});
```

## GraphQL Client

Execute GraphQL queries and mutations against `/graphql/graphql`.

### Methods

**execute(query, options)**

Execute a GraphQL query or mutation.

Parameters:
- `query`: GraphQL query string or GraphQLRequest object
- `options`: Execution options
  - `readOnly`: Whether this is a read-only query (boolean)

```javascript
// Simple query
const query = `
  query {
    jobs(filter: "JobStatus = 'Pending'") {
      edges {
        node {
          UID
          Name
        }
      }
    }
  }
`;

const result = await context.graphqlClient.execute(query, { readOnly: true });

// Query with variables
const queryWithVars = {
  query: `
    query GetJobs($status: String!) {
      jobs(filter: $status) {
        edges {
          node {
            UID
            Name
          }
        }
      }
    }
  `,
  variables: {
    status: "JobStatus = 'Pending'"
  }
};

const result2 = await context.graphqlClient.execute(queryWithVars, { readOnly: true });
```

## Config Variable Client

Manage configuration variables via `/configuration/extension` endpoints.

### Methods

**create(config)**

Create a new configuration variable.

Parameters:
- `config`: Configuration object
  - `key`: Variable name (string)
  - `value`: Variable value (string)
  - `configType`: Type of config (string): "plain-text", "secret", "json"
  - `description`: Variable description (string)

```javascript
await context.configVarClient.create({
  key: "EMAIL_SERVICE_URL",
  value: "https://api.email.com/v1",
  configType: "plain-text",
  description: "Email service API endpoint"
});

// Create secret
await context.configVarClient.create({
  key: "EMAIL_API_KEY",
  value: "secret-key-value",
  configType: "secret",
  description: "Email service API key"
});

// Create JSON config
await context.configVarClient.create({
  key: "EMAIL_SETTINGS",
  value: JSON.stringify({ timeout: 5000, retries: 3 }),
  configType: "json",
  description: "Email service settings"
});
```

**get(key)**

Retrieve a configuration variable.

Parameters:
- `key`: Variable name (string)

```javascript
const config = await context.configVarClient.get('EMAIL_SERVICE_URL');
console.log(config.value);
```

**update(key, updates)**

Update an existing configuration variable.

Parameters:
- `key`: Variable name (string)
- `updates`: Fields to update (object)

```javascript
await context.configVarClient.update('EMAIL_SERVICE_URL', {
  value: "https://api.email.com/v2",
  description: "Updated email service endpoint"
});
```

**delete(key)**

Delete a configuration variable.

Parameters:
- `key`: Variable name (string)

```javascript
await context.configVarClient.delete('OLD_CONFIG_VAR');
```

## Org Preferences Client

Manage organization preferences via `/config/org_preference` endpoint.

### Methods

**get()**

Retrieve current organization preferences.

Returns: Object with all org preferences

```javascript
const prefs = await context.orgPreferencesClient.get();

console.log(prefs.allowAbortJob);
console.log(prefs.defaultJobDuration);
```

**deploy(preferences)**

Update organization preferences.

Parameters:
- `preferences`: Object with preference updates

```javascript
const updates = {
  allowAbortJob: false,
  defaultJobDuration: 60,
  requireJobCompletionNotes: true
};

const updated = await context.orgPreferencesClient.deploy(updates);
```

## Config Features Client

Access feature flags via `/config/features` endpoint.

### Methods

**get()**

Retrieve current feature flag configuration.

Returns: Object with all feature flags

```javascript
const features = await context.configFeaturesClient.get();

if (features.newSchedulingEngine) {
  // Use new scheduling logic
}
```

## Mobile Notification Client

Send notifications and SMS via `/notifications` endpoints.

### Methods

**send(notification)**

Send a mobile notification.

Parameters:
- `notification`: Notification object
  - `resourceIds`: Array of resource IDs (string[])
  - `title`: Notification title (string)
  - `body`: Notification body (string)
  - `data`: Custom data payload (object, optional)

```javascript
await context.mobileNotificationClient.send({
  resourceIds: ["resource-id-1", "resource-id-2"],
  title: "New Job Assignment",
  body: "You have been assigned to JOB-12345",
  data: {
    jobId: "job-id-123",
    action: "view_job"
  }
});
```

**sendSMS(sms)**

Send an SMS message.

Parameters:
- `sms`: SMS object
  - `to`: Phone number (string)
  - `body`: Message body (string)

```javascript
await context.mobileNotificationClient.sendSMS({
  to: "+1234567890",
  body: "Your appointment is confirmed for tomorrow at 10am"
});
```

## Geo API Client

Access geolocation services via `/geo` endpoints.

### Methods

**getDistanceMatrix(origins, destinations, options)**

Calculate travel distance and time between locations.

Parameters:
- `origins`: Array of coordinates
- `destinations`: Array of coordinates
- `options`: Optional settings
  - `travelMode`: "driving", "walking", "bicycling", "transit"
  - `departureTime`: ISO timestamp for traffic calculation

```javascript
const origins = [
  { lat: 37.7749, lng: -122.4194 },  // San Francisco
  { lat: 37.3382, lng: -121.8863 }   // San Jose
];

const destinations = [
  { lat: 37.8044, lng: -122.2712 },  // Oakland
  { lat: 37.4419, lng: -122.1430 }   // Palo Alto
];

const matrix = await context.geoApiClient.getDistanceMatrix(
  origins, 
  destinations,
  { travelMode: "driving" }
);
```

**getAddressSuggestions(input, options)**

Get address autocomplete suggestions.

Parameters:
- `input`: Search text (string)
- `options`: Search options
  - `country`: Country code (string)
  - `types`: Place types to filter (string[])

```javascript
const suggestions = await context.geoApiClient.getAddressSuggestions(
  "123 Main St",
  { country: "US" }
);

suggestions.forEach(place => {
  console.log(place.formattedAddress);
  console.log(`Lat: ${place.geometry.lat}, Lng: ${place.geometry.lng}`);
});
```

**geocode(address)**

Convert address to coordinates.

Parameters:
- `address`: Address string (string)

```javascript
const location = await context.geoApiClient.geocode("1600 Amphitheatre Pkwy, Mountain View, CA");
console.log(`Lat: ${location.lat}, Lng: ${location.lng}`);
```

## Availability API Client

Check resource availability via `/availability` endpoints.

### Methods

**checkAvailability(resourceIds, startTime, endTime)**

Check if resources are available during a time window.

Parameters:
- `resourceIds`: Array of resource IDs (string[])
- `startTime`: Start time (ISO string)
- `endTime`: End time (ISO string)

```javascript
const available = await context.availabilityClient.checkAvailability(
  ["resource-1", "resource-2"],
  "2025-11-01T09:00:00Z",
  "2025-11-01T17:00:00Z"
);

available.forEach(result => {
  console.log(`${result.resourceId}: ${result.isAvailable}`);
});
```

## Files API Client

Manage file uploads and downloads via `/files` endpoints.

### Methods

**upload(file, metadata)**

Upload a file.

Parameters:
- `file`: File buffer or stream
- `metadata`: File metadata
  - `filename`: Name of file (string)
  - `contentType`: MIME type (string)
  - `tags`: File tags (string[], optional)

```javascript
const fileBuffer = Buffer.from(fileData);

const uploadResult = await context.filesClient.upload(fileBuffer, {
  filename: "report.pdf",
  contentType: "application/pdf",
  tags: ["report", "monthly"]
});

console.log(`File uploaded with ID: ${uploadResult.fileId}`);
```

**download(fileId)**

Download a file.

Parameters:
- `fileId`: File ID (string)

```javascript
const fileData = await context.filesClient.download("file-id-123");
```

## Artifact Client

Manage Pulse artifacts (functions, webhooks, data connectors) via `/artifacts` endpoints.

### Methods

**list()**

List all artifacts of a specific type.

```javascript
const artifactClient = context.newArtifactClient(ArtifactType.FUNCTION);
const functions = await artifactClient.list();

functions.forEach(func => {
  console.log(`${func.name}: ${func.status}`);
});
```

**get(name)**

Get details of a specific artifact.

Parameters:
- `name`: Artifact name (string)

```javascript
const artifact = await artifactClient.get("my-function");
console.log(artifact.configuration);
```

**create(artifact)**

Create a new artifact.

Parameters:
- `artifact`: Artifact definition (object)

```javascript
await artifactClient.create({
  name: "my-webhook",
  type: "webhook",
  configuration: {
    url: "https://example.com/webhook",
    method: "POST"
  }
});
```

**update(name, updates)**

Update an existing artifact.

Parameters:
- `name`: Artifact name (string)
- `updates`: Updated fields (object)

```javascript
await artifactClient.update("my-webhook", {
  configuration: {
    url: "https://example.com/new-webhook"
  }
});
```

**delete(name)**

Delete an artifact.

Parameters:
- `name`: Artifact name (string)

```javascript
await artifactClient.delete("old-webhook");
```
