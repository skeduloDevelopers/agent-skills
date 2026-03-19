---
name: skedulo-api-developer
description: Expert guidance for building high-performance solutions with Skedulo Pulse APIs. Use this skill when working with @skedulo/pulse-solution-services, implementing GraphQL queries and mutations, correct EQL syntax, managing batch operations, validating resources, or optimizing API performance in Pulse platform functions.
---

# Skedulo API Developer Skill

This skill provides expert patterns for building efficient, performant solutions on the Skedulo Pulse platform using `@skedulo/pulse-solution-services`.

## Core Principles

### Get a solid understanding of the Skedulo API
- Read https://docs.skedulo.com/skedulo-api/ and:
1. Understand the structure of all available API endpoints
2. Note authentication methods
3. Identify rate limits and constraints
4. Understand key GraphQL operations and EQL expressions

### Always Initialize Execution Context First

Every Pulse function starts with an execution context. This context provides access to all services and automatically adds tracking headers for observability.

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "project-name",
  userAgent: "function-name"
});
```

Set meaningful values for `requestSource` and `userAgent`. These appear in logs and help debug production issues.

### Respect Execution Limits

Default limits prevent runaway executions:
- 50 total API calls
- 5 concurrent requests
- 12 second max execution time

Override these limits when you need more capacity:

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "project-name",
  userAgent: "function-name",
  limits: {
    totalCalls: 100,
    maxConcurrentRequests: 10,
    maxMethodExecutionTimeMs: 20000,
    throwOnViolation: true
  }
});
```

Check execution metrics to optimize performance:

```javascript
console.log(context.getExecutionMetrics());
```

### Use the Right Client for Each API

The context provides specialized clients for different Skedulo APIs. Choose the right client to access proper validation, error handling, and retry logic.

## GraphQL Operations

### EQL filters   

-  Most of the GraphQL queries take a `filter` parameter, which is an _Elastic Query Language_ (EQL) filter string. EQL is a simple Domain Specific Language (DSL) that filters results.

It is similar to an SQL `WHERE` clause.

### Example: Query to fetch all queued jobs   
```graphql
    query {
      jobs(filter: "JobStatus == 'Queued'") {
        edges {
          node {
            UID
            Name
            Description
            JobStatus
          }
        }
      }
    }
```    

- An EQL filter is a boolean expression that can refer to the fields of the object being queried.

#### Operators   

| Operators | Description |
|-----------|-------------|
| `==`, `!=` | Equal To, Not Equal To |
| `<`, `<=`, `>`, `>=` | Comparison Operators |
| `LIKE` | Wildcard match (case insensitive, use % as a wildcard). |
| `NOTLIKE` | Wildcard match (case insensitive, use % as a wildcard). |
| `IN` | Determines if a value is in a list. |
| `NOTIN` | Determines if a value is not in a list. |
| `INCLUDES` | Determines whether a picklist includes a given value. |
| `EXCLUDES` | Determines whether a picklist excludes a given value. |
| `DISTANCE(field, GEOLOCATION(lat, lng))` | Calculate distance between a geolocation field and a fixed point (in meters). |
| `AND`, `OR` | Boolean expressions |
| `(SELECT <Field> FROM <Object> WHERE <Filter>)` | Apply a filter sub-query to a selected field. |

#### Literals   
| Type | Examples |
|------|----------|
| String | `"A String"`, `'A single quoted string'` |
| Null | `null` |
| Boolean | `true`, `false` |
| Integer | `997` |
| Floating Point | `25.96` |
| Instant | `2018-06-04T09:35:56.000Z` (note milliseconds are required) |
| Local Time | `09:35:05` |
| Local Date | `2018-06-04` |
| Duration | `15 minutes`, `1 hour` |
| GeoLocation | `GEOLOCATION(37.774900, -122.419400)` |


Some example filters:
- `Name == 'Skedulo'`
- `(Name == 'Skedulo' OR Description LIKE '%desc%') AND (Locked == true)`
- `Start == null`
- `Start > 2018-06-01T00:00:00.000Z`
- `Name IN ['Salesforce', 'Standalone']`
- `UserTypes INCLUDES 'Admin'`
- `Contact.Account.Name LIKE 'Jane%'`
- `UID IN (SELECT JobId FROM JobOffers WHERE Status != 'Closed')`
- `FirstName NOTIN ['Test', 'delete']`
- `UID NOTIN (SELECT UserId FROM Resources)`
- `UserTypes EXCLUDES 'Administrator'`
- `DISTANCE(GeoLocation, GEOLOCATION(-27.8, 153.3)) < 50000`
- `DISTANCE(GeoLocation, GEOLOCATION(37.774900, -122.419400)) > 1000 AND Name LIKE '%San Francisco%'`

#### Handling Date Values
The GraphQL schema expects `Instant` type values (without quotes) for date fields like `Start`. Follow the Correct example below.

**BAD**

```tsx
const filter = `AccountId == '${accountId}' AND Start >= '${startDate}' AND Start <= '${endDate}'`
// Result: AccountId == 'xxx' AND Start >= '2025-10-30T14:00:00.000Z' AND Start <= '2025-12-26T13:59:59.999Z'

```

**CORRECT**

```tsx
const filter = `AccountId == '${accountId}' AND Start >= ${startDate} AND Start <= ${endDate}`
// Result: AccountId == 'xxx' AND Start >= 2025-10-30T14:00:00.000Z AND Start <= 2025-12-26T13:59:59.999Z
```

### Query Patterns

Build queries using the query builder for type safety and automatic pagination support.

**Basic query:**

```javascript
const result = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
  .withFields(["UID", "Name", "JobStatus", "Start", "End"])
  .withFilter("JobStatus = 'Pending'")
  .withLimit(100)
  .execute();

const jobs = result.records;
```

**Query with relationships:**

```javascript
const queryBuilder = context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobsWithDetails" })
  .withFields(["UID", "Name", "Start", "End"]);

// Add parent relationship
queryBuilder.withParentQuery("Region").withFields(["UID", "Name"]);

// Add child relationship
queryBuilder.withChildQuery("JobAllocations").withFields(["UID", "Status"]);

const result = await queryBuilder.execute();
```

**Pagination strategies:**

Use offset pagination for small datasets:

```javascript
const results = await context.graphqlService.queryByPages(
  queryBuilder,
  { pageSize: 50, maxPages: 10 }
);

const allRecords = results.flatMap(r => r.records);
```

Use cursor pagination for large datasets (more efficient):

```javascript
const results = await context.graphqlService.queryByPages(
  queryBuilder,
  { 
    pageSize: 100, 
    maxPages: 20, 
    strategy: PaginationStrategy.CURSOR 
  }
);
```

### Mutation Patterns

**Single record update:**

```javascript
await context.graphqlService.mutate({
  objectName: "Jobs",
  operation: GraphqlOperations.UPDATE,
  operationName: "updateJob",
  records: [{
    UID: jobId,
    JobStatus: "Complete",
    ActualEnd: new Date().toISOString()
  }]
});
```

**Batch mutations (preferred for multiple records):**

```javascript
const recordsToUpdate = jobs.map(job => ({
  UID: job.UID,
  JobStatus: "Cancelled"
}));

await context.graphqlService.mutate({
  objectName: "Jobs",
  operation: GraphqlOperations.UPDATE,
  operationName: "bulkUpdateJobs",
  records: recordsToUpdate
});
```

**Upsert with external ID:**

```javascript
await context.graphqlService.upsert({
  objectName: "Contacts",
  operationName: "upsertContacts",
  externalIdField: "ExternalId__c",
  records: [{
    ExternalId__c: "EXT-12345",
    FirstName: "John",
    LastName: "Smith"
  }]
});
```

### Performance Optimization

**Batch multiple queries:**

Execute multiple independent queries concurrently to reduce total execution time:

```javascript
const [jobs, resources, regions] = await Promise.all([
  context.graphqlService.query(jobQuery),
  context.graphqlService.query(resourceQuery),
  context.graphqlService.query(regionQuery)
]);
```

**Use specific fields:**

Only request fields you need. Avoid selecting all fields:

```javascript
// Good: specific fields only
.withFields(["UID", "Name", "Start"])

// Avoid: selecting everything
.withFields(["*"])
```

**Limit data retrieval:**

Apply filters and limits to reduce data transfer:

```javascript
const queryBuilder = context
  .newQueryBuilder({ objectName: "Jobs", operationName: "recentJobs" })
  .withFilter(`Start >= '${startDate}' AND Start <= '${endDate}'`)
  .withLimit(200);
```

## Batch Processing

Use the Batch Service for processing large datasets efficiently. The service handles pagination automatically and processes records in manageable chunks.

**Create a batch processor:**

```javascript
import { GraphBatch, GraphqlOperations } from "@skedulo/pulse-solution-services";

export class ProcessJobs extends GraphBatch {
  protected async start() {
    return this.context
      .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
      .withFields(["UID", "Name", "Start"])
      .withFilter("JobStatus = 'Pending'")
      .withOrderBy("Start ASC");
  }

  protected async execute(records) {
    // Process each batch
    const updates = records.map(job => ({
      UID: job.UID,
      ProcessedDate: new Date().toISOString()
    }));

    await this.context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.UPDATE,
      operationName: "updateJobs",
      records: updates
    });
  }

  protected async finish() {
    this.context.logger.info("Batch processing complete");
  }
}
```

**Run the batch:**

```javascript
const batch = new ProcessJobs(context, {
  batchSize: 50,
  maxBatches: 20,
  strategy: PaginationStrategy.CURSOR,
  delaySeconds: 1
});

await batch.run();
```

**Unique batch execution:**

Prevent concurrent batch runs using `UniqueGraphBatch`:

```javascript
export class UniqueProcessJobs extends UniqueGraphBatch {
  // Same implementation as GraphBatch
}

const batch = new UniqueProcessJobs(context, {
  batchSize: 50,
  lockTtl: 5 * 60 * 1000  // 5 minutes
});

await batch.run();  // Succeeds
await batch.run();  // Fails with lock error
```

## Resource Validation

Validate resources against jobs to check availability, conflicts, and skill requirements.

**Basic validation:**

```javascript
import { ResourceValidator, EntityFactory } from "@skedulo/pulse-solution-services";

// Fetch resources and jobs
const resourcesResult = await context
  .newQueryBuilder({ objectName: "Resources", operationName: "fetchResources" })
  .withFields(["UID", "Name", "Category"])
  .execute();

const jobsResult = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
  .withFields(["UID", "Name", "Start", "End"])
  .execute();

// Convert to entities
const resources = resourcesResult.records.map(r => EntityFactory.createResource(r));
const jobs = jobsResult.records.map(j => EntityFactory.createJob(j));

// Validate
const validator = new ResourceValidator({
  checkAvailability: true,
  checkConflict: true,
  checkTag: true
});

const result = validator.validate(resources, jobs);

// Get qualified resources
const qualified = result.getQualifiedResources();
const jobsWithResources = result.getJobsWithXQualifiedResources(2);
```

## API Clients

### Metadata Client

Fetch schema metadata for objects:

```javascript
// Get all metadata
const allMetadata = await context.metadataClient.fetchAllMetadata();

// Get specific object metadata
const jobMetadata = await context.metadataClient.fetchObjectMetadata('Jobs');
```

### Vocabulary Client

Manage picklist values:

```javascript
// Get picklist values
const items = await context.vocabularyClient.getVocabularyItems('Jobs', 'JobType');

// Add new value
await context.vocabularyClient.addVocabularyItem('Jobs', 'JobType', {
  value: "Emergency",
  label: "Emergency Service",
  active: true
});

// Update existing value
await context.vocabularyClient.updateVocabularyItem('Jobs', 'JobType', 'Repair', {
  label: "Repair Service (Updated)"
});
```

### Config Variable Client

Manage configuration variables:

```javascript
// Create config variable
await context.configVarClient.create({
  key: "API_TIMEOUT",
  value: "30000",
  configType: "plain-text",
  description: "API timeout in milliseconds"
});

// Get config variable
const config = await context.configVarClient.get('API_TIMEOUT');

// Delete config variable
await context.configVarClient.delete('API_TIMEOUT');
```

### Geo Service

Handle geolocation operations:

```javascript
// Calculate distance matrix
const origins = [{ lat: 55.93, lng: -3.118 }];
const destinations = [{ lat: 50.087, lng: 14.421 }];

const matrix = await context.geoService.getDistanceMatrix(origins, destinations);

for (const origin of origins) {
  for (const destination of destinations) {
    const key = context.geoService.createKey(origin, destination);
    const entry = matrix.get(key);
    
    if (entry?.status === "OK") {
      console.log(`Distance: ${entry.distance.distanceInMeters}m`);
      console.log(`Duration: ${entry.duration.durationInSeconds}s`);
    }
  }
}

// Get address suggestions
const suggestions = await context.geoService.getAddressSuggestions(
  { input: "1600 Amphitheatre Pkwy", country: "US" },
  5
);
```

## Caching and Performance

### Cache Service

Cache expensive operations to improve performance:

```javascript
// Multi-layer cache with secondary persistence
const metadata = await context.inMemoryCache.get("METADATA", {
  useSecondaryCache: true
});

if (!metadata) {
  const fetched = await context.metadataClient.fetchAllMetadata();
  await context.inMemoryCache.set("METADATA", fetched, {
    useSecondaryCache: true
  });
}
```

### Lock Service

Prevent concurrent execution:

```javascript
// Acquire lock
const acquired = await context.lockService.acquireLock({
  name: 'CRITICAL_PROCESS',
  ttl: 5 * 60 * 1000  // 5 minutes
});

if (!acquired) {
  throw new Error("Process already running");
}

try {
  // Execute critical process
} finally {
  await context.lockService.releaseLock('CRITICAL_PROCESS');
}
```

## Error Handling

Always wrap API calls in try-catch blocks and provide meaningful error messages:

```javascript
try {
  const result = await context.graphqlService.query(queryBuilder);
  return result.records;
} catch (error) {
  context.logger.error("Failed to query jobs", { error: error.message });
  throw new Error(`Job query failed: ${error.message}`);
}
```

## Configuration Access

Access function configuration variables:

```javascript
// Get config values
const apiKey = context.configHelper.getString('API_KEY');
const timeout = context.configHelper.getNumber('TIMEOUT_MS');
const settings = context.configHelper.getJson('SETTINGS');
```

## Logging

Use structured logging for better observability:

```javascript
context.logger.info("Processing started", { 
  jobCount: jobs.length,
  batchSize: 50 
});

context.logger.error("Processing failed", { 
  error: error.message,
  stack: error.stack 
});
```

Add method logging with decorators:

```javascript
import { LogMethod } from "@skedulo/pulse-solution-services";

class JobService {
  @LogMethod("job_service")
  async processJob(jobId) {
    // Method calls are automatically logged
  }
}
```

Control logging with environment variables:
- `LOG_NAMESPACE`: Filter logs by namespace
- `LOG_ENTRY_MAX_LENGTH`: Set max log entry length (default 120)

## Common Patterns

### Pattern: Process Jobs by Status

```javascript
async function processJobsByStatus(context, status) {
  const queryBuilder = context
    .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
    .withFields(["UID", "Name", "JobStatus", "Start"])
    .withFilter(`JobStatus = '${status}'`)
    .withLimit(100);

  const result = await queryBuilder.execute();
  return result.records;
}
```

### Pattern: Bulk Update with Error Handling

```javascript
async function bulkUpdateJobs(context, updates) {
  try {
    await context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.UPDATE,
      operationName: "bulkUpdate",
      records: updates
    });
    context.logger.info(`Updated ${updates.length} jobs`);
  } catch (error) {
    context.logger.error("Bulk update failed", { 
      count: updates.length,
      error: error.message 
    });
    throw error;
  }
}
```

### Pattern: Query with Pagination

```javascript
async function getAllJobs(context) {
  const queryBuilder = context
    .newQueryBuilder({ objectName: "Jobs", operationName: "getAllJobs" })
    .withFields(["UID", "Name", "Start"]);

  const pages = await context.graphqlService.queryByPages(queryBuilder, {
    pageSize: 100,
    maxPages: 50,
    strategy: PaginationStrategy.CURSOR
  });

  return pages.flatMap(page => page.records);
}
```

## Best Practices Summary

1. **Initialize context with meaningful identifiers** for debugging
2. **Set appropriate execution limits** based on your function's needs
3. **Use cursor pagination** for datasets over 1000 records
4. **Batch multiple independent queries** with Promise.all
5. **Select only needed fields** to reduce data transfer
6. **Use GraphBatch** for processing large datasets
7. **Implement proper error handling** with try-catch blocks
8. **Cache expensive operations** to improve performance
9. **Use UniqueGraphBatch** to prevent duplicate runs
10. **Log structured data** for better observability
11. **ALWAYS use proper types** instead of `any`. Validate props with Typescript
