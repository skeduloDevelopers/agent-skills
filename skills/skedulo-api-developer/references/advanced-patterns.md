# Advanced Patterns and Recipes

This file contains advanced patterns and complete recipes for common Skedulo development scenarios.

PSS (`@skedulo/pulse-solution-services`) examples use JavaScript syntax. PSF (`@skedulo/pulse-solutions-framework`) examples use TypeScript — PSF is a typed layer and requires type annotations to get full benefit from change detection and object definitions.

## Table of Contents

1. [Error Handling Patterns](#error-handling-patterns)
2. [Retry Mechanisms](#retry-mechanisms)
3. [Transaction Patterns](#transaction-patterns)
4. [Data Migration](#data-migration)
5. [Webhook Processing](#webhook-processing)
6. [Scheduled Job Patterns](#scheduled-job-patterns)
7. [Complex Queries](#complex-queries)
8. [Performance Optimization](#performance-optimization)
   - [Understanding Execution Limits](#understanding-execution-limits)
   - [PSS Patterns](#pss-patterns) (`@skedulo/pulse-solution-services`)
   - [PSF Patterns](#psf-patterns) (`@skedulo/pulse-solutions-framework`)

## Error Handling Patterns

### Pattern: Retry with Exponential Backoff

Use exponential backoff for transient failures:

```javascript
async function retryWithBackoff(fn, maxRetries = 3, baseDelay = 1000) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      
      const delay = baseDelay * Math.pow(2, attempt);
      context.logger.warn(`Retry attempt ${attempt + 1} after ${delay}ms`, {
        error: error.message
      });
      
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

// Usage
const result = await retryWithBackoff(async () => {
  return await context.graphqlService.query(queryBuilder);
}, 3, 1000);
```

### Pattern: Partial Success Handling

Handle scenarios where some operations succeed and others fail:

```javascript
async function bulkUpdateWithErrorTracking(context, updates) {
  const results = {
    successful: [],
    failed: []
  };

  for (const update of updates) {
    try {
      await context.graphqlService.mutate({
        objectName: "Jobs",
        operation: GraphqlOperations.UPDATE,
        operationName: "updateJob",
        records: [update]
      });
      results.successful.push(update.UID);
    } catch (error) {
      results.failed.push({
        uid: update.UID,
        error: error.message
      });
    }
  }

  context.logger.info("Bulk update completed", {
    successful: results.successful.length,
    failed: results.failed.length
  });

  return results;
}
```

### Pattern: Circuit Breaker

Prevent cascading failures:

```javascript
class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.failureCount = 0;
    this.threshold = threshold;
    this.timeout = timeout;
    this.state = 'CLOSED';
    this.nextAttempt = Date.now();
  }

  async execute(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() < this.nextAttempt) {
        throw new Error('Circuit breaker is OPEN');
      }
      this.state = 'HALF_OPEN';
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failureCount++;
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.timeout;
    }
  }
}

// Usage
const breaker = new CircuitBreaker(5, 60000);

async function makeApiCall() {
  return await breaker.execute(async () => {
    return await context.graphqlService.query(queryBuilder);
  });
}
```

> Circuit Breaker and [Retry with Exponential Backoff](#pattern-retry-with-exponential-backoff) solve adjacent problems — use retries for transient failures, circuit breakers for persistent downstream degradation.

## Retry Mechanisms

### Pattern: Idempotent Operations

Ensure operations can be safely retried:

```javascript
async function upsertJobWithIdempotency(context, jobData) {
  const externalId = jobData.externalId || `JOB-${Date.now()}-${Math.random()}`;
  
  return await context.graphqlService.upsert({
    objectName: "Jobs",
    operationName: "upsertJob",
    externalIdField: "ExternalId__c",
    records: [{
      ExternalId__c: externalId,
      ...jobData
    }]
  });
}
```

### Pattern: Distributed Lock with Retry

Always release the lock in a `finally` block — a missing release leaves the lock held for the full TTL, blocking all other executions until it auto-expires:

```javascript
async function runWithLock(context, lockName, ttl, fn) {
  const acquired = await context.lockService.acquireLock({ name: lockName, ttl });

  if (!acquired) {
    // Lock held by another execution — not an error, just skip or reschedule
    context.logger.warn(`Lock '${lockName}' already held — skipping this execution`);
    return null;
  }

  try {
    return await fn();
  } finally {
    // Always release, even if fn() throws
    await context.lockService.releaseLock({ name: lockName });
  }
}

// Usage
await runWithLock(context, 'SYNC_JOBS', 10 * 60 * 1000, async () => {
  // critical section — only one execution at a time
  await syncJobs(context);
});
```

**TTL guidance:** Set `ttl` = your maximum expected execution time + a safety buffer (e.g. `maxMethodExecutionTimeMs + 30s`). Too short → double-execution if the function runs slow. Too long → stuck lock after a crash blocks the next scheduled run.

**Retry with backoff** when you want to wait for the lock rather than skip:

```javascript
async function acquireLockWithRetry(context, lockName, options = {}) {
  const { maxRetries = 5, retryDelay = 2000, ttl = 5 * 60 * 1000 } = options;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const acquired = await context.lockService.acquireLock({ name: lockName, ttl });
    if (acquired) return true;
    if (attempt < maxRetries - 1) {
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }
  return false;
}

const locked = await acquireLockWithRetry(context, 'SYNC_JOBS', {
  maxRetries: 5,
  retryDelay: 2000,
  ttl: 10 * 60 * 1000
});

if (!locked) {
  throw new Error('Could not acquire lock after retries');
}
// always pair with releaseLock in finally
```

> `UniqueGraphBatch` uses `LockService` internally — its `lockTtl` option follows the same TTL guidance above. See [Large Dataset Processing with GraphBatch](#pattern-large-dataset-processing-with-graphbatch).

## Transaction Patterns

### Pattern: Compensating Transactions

Implement rollback logic for multi-step operations:

```javascript
async function createJobWithAllocations(context, jobData, allocations) {
  let createdJobId = null;
  let createdAllocationIds = [];

  try {
    // Step 1: Create job
    const jobResult = await context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.INSERT,
      operationName: "createJob",
      records: [jobData]
    });
    createdJobId = jobResult.insertJob.UID;

    // Step 2: Create allocations
    const allocationRecords = allocations.map(alloc => ({
      ...alloc,
      JobId: createdJobId
    }));

    const allocResult = await context.graphqlService.mutate({
      objectName: "JobAllocations",
      operation: GraphqlOperations.INSERT,
      operationName: "createAllocations",
      records: allocationRecords
    });
    createdAllocationIds = allocResult.insertJobAllocations.map(a => a.UID);

    return { jobId: createdJobId, allocationIds: createdAllocationIds };

  } catch (error) {
    // Rollback: delete allocations and job
    if (createdAllocationIds.length > 0) {
      await context.graphqlService.mutate({
        objectName: "JobAllocations",
        operation: GraphqlOperations.DELETE,
        operationName: "deleteAllocations",
        records: createdAllocationIds.map(id => ({ UID: id }))
      });
    }

    if (createdJobId) {
      await context.graphqlService.mutate({
        objectName: "Jobs",
        operation: GraphqlOperations.DELETE,
        operationName: "deleteJob",
        records: [{ UID: createdJobId }]
      });
    }

    throw error;
  }
}
```

> When a batch is atomic enough (all-or-nothing is acceptable), use `mutateBatch` instead of compensating logic. See [Batch Multiple Mutations in One Request](#pattern-batch-multiple-mutations-in-one-request).

### Pattern: Two-Phase Commit

Validate before committing changes:

```javascript
async function updateJobsWithValidation(context, updates) {
  // Phase 1: Fetch all jobs in one query (avoids N+1 individual queries)
  const uidList = updates.map(u => u.UID).join("','");
  const jobsResult = await context.graphqlService.query(
    context.newQueryBuilder({ objectName: "Jobs", operationName: "getJobs", readOnly: true })
      .withFields(["UID", "JobStatus", "Start"])
      .withFilter(`UID IN ('${uidList}')`)
      .withLimit(updates.length)
  );

  const jobMap = new Map(jobsResult.records.map(j => [j.UID, j]));

  const validationResults = updates.map(update => {
    const job = jobMap.get(update.UID);
    if (!job) return { uid: update.UID, valid: false, reason: "Job not found" };
    return { uid: update.UID, valid: validateUpdate(job, update) };
  });

  // Check if all valid
  const allValid = validationResults.every(r => r.valid);
  if (!allValid) {
    const invalid = validationResults.filter(r => !r.valid);
    throw new Error(`Validation failed for jobs: ${JSON.stringify(invalid)}`);
  }

  // Phase 2: Execute all updates
  await context.graphqlService.mutate({
    objectName: "Jobs",
    operation: GraphqlOperations.UPDATE,
    operationName: "bulkUpdate",
    records: updates
  });

  return validationResults;
}

function validateUpdate(currentJob, update) {
  // Add validation logic
  if (update.JobStatus === 'Complete' && !currentJob.Start) {
    return false;
  }
  return true;
}
```

## Data Migration

### Pattern: Staged Migration

Migrate data in stages with checkpoints:

```javascript
import { GraphBatch } from "@skedulo/pulse-solution-services";

class DataMigration extends GraphBatch {
  constructor(context, options) {
    super(context, options);
    this.checkpointKey = `MIGRATION_CHECKPOINT_${options.migrationId}`;
  }

  protected async start() {
    // Load checkpoint
    const checkpoint = await this.loadCheckpoint();
    
    const queryBuilder = this.context
      .newQueryBuilder({ objectName: "Jobs", operationName: "migrateJobs" })
      .withFields(["UID", "Name", "Description"])
      .withOrderBy("CreatedDate ASC");

    if (checkpoint) {
      queryBuilder.withFilter(`CreatedDate > '${checkpoint.lastProcessedDate}'`);
    }

    return queryBuilder;
  }

  protected async execute(records) {
    const transformed = records.map(record => ({
      UID: record.UID,
      Description: this.transformData(record.Description),
      MigrationStatus__c: "Migrated"
    }));

    await this.context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.UPDATE,
      operationName: "updateMigrated",
      records: transformed
    });

    // Save checkpoint
    await this.saveCheckpoint({
      lastProcessedDate: records[records.length - 1].CreatedDate,
      processedCount: records.length
    });
  }

  transformData(description) {
    // Migration logic
    return description ? description.toUpperCase() : "";
  }

  async loadCheckpoint() {
    try {
      const config = await this.context.configVarClient.get(this.checkpointKey);
      return JSON.parse(config.value);
    } catch {
      return null;
    }
  }

  async saveCheckpoint(data) {
    try {
      await this.context.configVarClient.update(this.checkpointKey, {
        value: JSON.stringify(data)
      });
    } catch {
      await this.context.configVarClient.create({
        key: this.checkpointKey,
        value: JSON.stringify(data),
        configType: "plain-text",
        description: "Migration checkpoint"
      });
    }
  }
}

// Run migration
const migration = new DataMigration(context, {
  migrationId: "JOB_DESCRIPTION_MIGRATION",
  batchSize: 100,
  maxBatches: 50,
  strategy: PaginationStrategy.CURSOR
});

await migration.run();
```

## Webhook Processing

### Pattern: Webhook Handler with Validation

Process webhooks with signature verification:

```javascript
async function processWebhook(context, payload, signature) {
  // Verify signature
  if (!verifySignature(payload, signature)) {
    throw new Error("Invalid webhook signature");
  }

  // Parse payload
  const data = JSON.parse(payload);

  // Handle different event types
  switch (data.eventType) {
    case 'job.created':
      await handleJobCreated(context, data);
      break;
    case 'job.updated':
      await handleJobUpdated(context, data);
      break;
    case 'job.cancelled':
      await handleJobCancelled(context, data);
      break;
    default:
      context.logger.warn(`Unknown event type: ${data.eventType}`);
  }
}

async function handleJobCreated(context, data) {
  context.logger.info("Processing job created event", { jobId: data.jobId });

  // Query job details
  const job = await context.graphqlService.query(
    context.newQueryBuilder({ objectName: "Jobs", operationName: "getJob" })
      .withFields(["UID", "Name", "Start", "End", "Region.Name"])
      .withFilter(`UID = '${data.jobId}'`)
  );

  if (!job.records[0]) {
    throw new Error(`Job not found: ${data.jobId}`);
  }

  // Send notification
  await context.mobileNotificationClient.send({
    resourceIds: data.assignedResourceIds,
    title: "New Job Assignment",
    body: `You have been assigned to ${job.records[0].Name}`,
    data: { jobId: data.jobId }
  });
}

function verifySignature(payload, signature) {
  // Implement signature verification
  return true;
}
```

## Scheduled Job Patterns

### Pattern: Daily Cleanup Job

Use `UniqueGraphBatch` for scheduled operations — it acquires a distributed lock so concurrent triggers (e.g. overlapping cron firings) don't double-process. See the full implementation under [PSS Patterns → Large Dataset Processing with GraphBatch](#pattern-large-dataset-processing-with-graphbatch).

**Scheduling guidance:**

- Set `lockTtl` to your maximum expected run time + buffer. If a run is still in progress when the next trigger fires, the second call detects the held lock and exits cleanly.
- All date comparisons in filters should use ISO 8601 UTC strings — compute the cutoff at runtime rather than hardcoding it.
- Log `getExecutionMetrics()` at the end of `finish()` to track call budget usage across runs.
- For dead-letter handling (jobs that were never processed), add a separate scheduled function that queries for records in an unexpected state after the normal window.

## Complex Queries

### Pattern: Multi-Level Relationship Query

Query deeply nested relationships:

```javascript
async function getJobsWithFullDetails(context) {
  const queryBuilder = context
    .newQueryBuilder({ objectName: "Jobs", operationName: "getDetailedJobs" })
    .withFields(["UID", "Name", "Start", "End", "JobStatus"]);

  // Add Region (parent)
  queryBuilder
    .withParentQuery("Region")
    .withFields(["UID", "Name", "Timezone"]);

  // Add Account (parent)
  queryBuilder
    .withParentQuery("Account")
    .withFields(["UID", "Name", "Phone"]);

  // Add Contact (through Account)
  const accountQuery = queryBuilder.getParentQuery("Account");
  accountQuery
    .withParentQuery("PrimaryContact")
    .withFields(["UID", "FirstName", "LastName", "Email"]);

  // Add JobAllocations (children)
  queryBuilder
    .withChildQuery("JobAllocations")
    .withFields(["UID", "Status", "EstimatedTravelTime"]);

  // Add Resource details (through JobAllocations)
  const allocQuery = queryBuilder.getChildQuery("JobAllocations");
  allocQuery
    .withParentQuery("Resource")
    .withFields(["UID", "Name", "Category"]);

  const result = await queryBuilder.execute();
  return result.records;
}
```

### Pattern: Aggregation Query

Calculate aggregated metrics:

```javascript
async function getJobStatsByRegion(context, startDate, endDate) {
  const query = `
    query JobStats {
      jobs(filter: "Start >= '${startDate}' AND Start <= '${endDate}'") {
        edges {
          node {
            UID
            JobStatus
            Duration
            Region {
              UID
              Name
            }
          }
        }
      }
    }
  `;

  // Use raw graphqlClient when QueryBuilder can't express the shape (e.g. nested aggregations).
  // This still counts against totalCalls and is tracked in getExecutionMetrics().
  const result = await context.graphqlClient.execute(query, { readOnly: true });
  const jobs = result.data.jobs.edges.map(e => e.node);

  // Group by region
  const statsByRegion = jobs.reduce((acc, job) => {
    const regionId = job.Region.UID;
    
    if (!acc[regionId]) {
      acc[regionId] = {
        regionName: job.Region.Name,
        totalJobs: 0,
        completedJobs: 0,
        totalDuration: 0
      };
    }

    acc[regionId].totalJobs++;
    if (job.JobStatus === 'Complete') {
      acc[regionId].completedJobs++;
    }
    acc[regionId].totalDuration += job.Duration || 0;

    return acc;
  }, {});

  return statsByRegion;
}
```

## Performance Optimization

### Understanding Execution Limits

Every `ExecutionContext` enforces three limits by default. Violating them logs a warning (or throws if `throwOnViolation: true`):

| Limit | Default | Config key | Applies to |
| ----- | ------- | ---------- | ---------- |
| Total API calls | 50 | `totalCalls` | All calls (GraphQL + non-GraphQL) |
| Concurrent requests | 5 | `maxConcurrentRequests` | **Non-GraphQL only** (geo, metadata, notifications) |
| Per-method execution time | 12 000 ms | `maxMethodExecutionTimeMs` | All methods |

**Important:** `maxConcurrentRequests` does **not** apply to GraphQL queries and mutations — the GraphQL endpoint has its own 40-connection pool limit on the elastic server. Concurrency of GraphQL calls is managed at the infrastructure level, not by this threshold. The `maxConcurrentRequests` limit is relevant when calling non-GraphQL services (geo lookups, metadata, mobile push notifications, artifact client).

`totalCalls` counts all API calls regardless of type. Design your function around this budget. Override limits explicitly when your use case requires more capacity:

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "my-project",
  userAgent: "my-function",
  limits: {
    totalCalls: 100,
    maxConcurrentRequests: 10,
    maxMethodExecutionTimeMs: 20000,
    throwOnViolation: true  // fail fast during development
  }
});
```

Always check metrics after a run to understand actual usage:

```javascript
console.log(context.getExecutionMetrics());
// { totalCalls: 12, peakConcurrentRequests: 3, methodStats: { ... } }
```

### PSS Patterns

`QueryBuilder` is the primary API for reads — chain `.withFields()`, `.withFilter()`, `.withOrderBy()`, `.withLimit()`, then call `.execute()` or pass the builder to `queryBatch`. For writes, use `graphqlService.mutate()` / `mutateBatch()` / `upsert()`. Both flows run through the same `ExecutionContext` call budget.

### Pattern: Batch Multiple Queries in One Request

`graphqlService.queryBatch` sends multiple independent queries to the GraphQL batch endpoint in a single API call — uses 1 call against your limit instead of N:

```javascript
const jobQueryBuilder = context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs", readOnly: true })
  .withFields(["UID", "Name", "JobStatus", "Start"])
  .withFilter("JobStatus != 'Complete'")
  .withLimit(100);

const regionQueryBuilder = context
  .newQueryBuilder({ objectName: "Regions", operationName: "fetchRegions", readOnly: true })
  .withFields(["UID", "Name", "Timezone"]);

const resourceQueryBuilder = context
  .newQueryBuilder({ objectName: "Resources", operationName: "fetchResources", readOnly: true })
  .withFields(["UID", "Name", "IsActive"])
  .withFilter("IsActive == true");

// 1 API call instead of 3
const [jobResult, regionResult, resourceResult] = await context.graphqlService.queryBatch([
  jobQueryBuilder,
  regionQueryBuilder,
  resourceQueryBuilder
]);

console.log(jobResult.records, regionResult.records, resourceResult.records);
```

Prefer `queryBatch` over `Promise.all` for independent GraphQL reads — it counts as **1 call** against `totalCalls` instead of N, and reduces round-trips to the GraphQL endpoint.

**Error handling:** `queryBatch` and `mutateBatch` are all-or-nothing — if any sub-operation fails, the entire batch throws. The error message includes the failing index (`"GraphQL batch error at index N: ..."`). Wrap the call in `try/catch` and decide whether to fall back to individual calls or fail fast:

```javascript
try {
  const [jobResult, regionResult] = await context.graphqlService.queryBatch([
    jobQueryBuilder,
    regionQueryBuilder
  ]);
  // use results
} catch (error) {
  context.logger.error('Batch query failed', { error: error.message });
  // error.message contains the index of the failing sub-operation
  // fall back to individual queries, or rethrow
  throw error;
}
```

### Pattern: Batch Multiple Mutations in One Request

`graphqlService.mutateBatch` sends multiple mutations in a single API call:

```javascript
const insertParams = {
  objectName: "Jobs",
  operationName: "insertJobs",
  operation: GraphqlOperations.INSERT,
  records: newJobs,
  bulkOperation: true
};

const updateParams = {
  objectName: "JobAllocations",
  operationName: "updateAllocations",
  operation: GraphqlOperations.UPDATE,
  records: allocationsToUpdate,
  suppressChangeEvents: true  // skip change history for bulk ops
};

const deleteParams = {
  objectName: "Activities",
  operationName: "deleteActivities",
  operation: GraphqlOperations.DELETE,
  records: activitiesToDelete.map(a => ({ UID: a.UID }))
};

// 1 API call instead of 3
const [insertResult, updateResult, deleteResult] = await context.graphqlService.mutateBatch([
  insertParams,
  updateParams,
  deleteParams
]);

const insertedUIDs = context.graphqlService.extractUIDs(insertResult);
```

### Pattern: Large Dataset Processing with GraphBatch

For processing large record sets, use `GraphBatch` instead of manual pagination. It handles pagination automatically, respects `delaySeconds` between batches to avoid rate limits, and stays within the `maxBatches` ceiling:

```javascript
import { GraphBatch, GraphqlOperations, PaginationStrategy } from "@skedulo/pulse-solution-services";

class UpdateJobDescriptions extends GraphBatch {
  protected async start() {
    return this.context
      .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
      .withFields(["UID", "Name", "Start", "Region.Name"])
      .withFilter("JobStatus != 'Cancelled'")
      .withOrderBy("CreatedDate ASC");
  }

  protected async execute(records) {
    const updates = records.map(job => ({
      UID: job.UID,
      Description: `${job.Name} — ${job.Region?.Name ?? "Unknown region"}`
    }));

    await this.context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.UPDATE,
      operationName: "updateJobDescriptions",
      records: updates,
      bulkOperation: true,
      suppressChangeEvents: true
    });
  }

  protected async finish() {
    this.context.logger.info("Batch complete", this.context.getExecutionMetrics());
  }
}

const batch = new UpdateJobDescriptions(context, {
  batchSize: 200,       // max 200 per batch (hard ceiling)
  maxBatches: 100,      // max 100 batches (hard ceiling: 500)
  strategy: PaginationStrategy.CURSOR,  // prefer CURSOR for large sets
  delaySeconds: 1       // pause 1s between batches to avoid rate limits (max: 15)
});

await batch.run();
```

**Overridable lifecycle methods:**

| Method | Required | Called | Throwing aborts the batch |
| ------ | -------- | ------ | ------------------------- |
| `start()` | Yes | Once, before pagination | Yes — batch never starts |
| `execute(records)` | Yes | Once per page | Yes — remaining pages are skipped |
| `finish()` | No | Once after all pages complete | No effect on already-processed records |

There is no built-in per-batch error recovery — wrap `execute()` body in `try/catch` if you want to log and continue rather than abort on a page failure.

Use `UniqueGraphBatch` when the batch must not run concurrently (e.g. scheduled jobs):

```javascript
import { UniqueGraphBatch } from "@skedulo/pulse-solution-services";

class DailyCleanup extends UniqueGraphBatch {
  protected async start() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    return this.context
      .newQueryBuilder({ objectName: "Jobs", operationName: "fetchExpired" })
      .withFields(["UID"])
      .withFilter(`JobStatus == 'Cancelled' AND CreatedDate < ${cutoff}`);
  }

  protected async execute(records) {
    await this.context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.DELETE,
      operationName: "deleteExpired",
      records: records.map(r => ({ UID: r.UID }))
    });
  }
}

const cleanup = new DailyCleanup(context, {
  batchSize: 200,
  maxBatches: 50,
  strategy: PaginationStrategy.CURSOR,
  lockTtl: 30 * 60 * 1000  // 30-minute lock (default: 16 minutes)
});

await cleanup.run();  // acquires distributed lock — second call fails until lock expires
```

If the lock is already held (e.g. a previous scheduled run is still in progress), `run()` throws. Catch this to distinguish "already running" from a genuine error:

```javascript
try {
  await cleanup.run();
} catch (error) {
  if (error.message?.includes('lock')) {
    context.logger.warn('Batch already running — skipping this trigger');
    return;
  }
  throw error;
}
```

### Pattern: Select Only the Fields You Need

Every field you add to `withFields` increases response payload size and query time. Only request what the function actually uses:

```javascript
// Good — minimal fields
const result = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobsForUpdate", readOnly: true })
  .withFields(["UID", "JobStatus", "Start"])
  .withFilter("JobStatus == 'Queued'")
  .withLimit(200)
  .execute();

// Avoid — fetching everything
const result = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs", readOnly: true })
  .withFields(["*"])
  .execute();
```

Also mark queries as `readOnly: true` whenever you are not mutating — this adds the `X-Skedulo-Read-Only` header which allows the platform to optimize the request.

### Pattern: Cursor Pagination for Large Datasets

For result sets over ~1 000 records, cursor pagination is more efficient than offset pagination — it avoids re-scanning skipped rows on each page:

```javascript
// Offset pagination — avoid for large sets
while (result.pageInfo.hasNextPage) {
  queryBuilder.withOffset(result.endOffset + 1);
  result = await queryBuilder.execute();
}

// Cursor pagination — preferred
while (result.pageInfo.hasNextPage) {
  queryBuilder.withCursor(result.endCursor);
  result = await queryBuilder.execute();
}

// Or use executeAll (up to 20 pages)
const allPages = await queryBuilder.executeAll(1, 20);
const allRecords = allPages.flatMap(p => p.records);
```

> For very large datasets (thousands of records), prefer `GraphBatch` over manual pagination — it handles cursor pagination automatically and respects rate limits between pages. See [Large Dataset Processing with GraphBatch](#pattern-large-dataset-processing-with-graphbatch).

### Pattern: Caching Expensive Operations

Use `context.inMemoryCache` to avoid redundant API calls. There are two scopes:

- **In-memory (default):** lives for the current function invocation only — safe for any data.
- **Secondary cache (`useSecondaryCache: true`):** persists across invocations via configVars — only use for data that rarely changes (object metadata, config values). Changes made outside the function won't be reflected until the cache entry expires or is explicitly deleted.

```javascript
async function getMetadataWithCache(context, objectName) {
  const cacheKey = `METADATA_${objectName}`;

  // Try secondary cache first (persists across invocations)
  const cached = await context.inMemoryCache.get(cacheKey, { useSecondaryCache: true });
  if (cached) return cached;

  // Cache miss — fetch and store
  const metadata = await context.metadataClient.fetchObjectMetadata(objectName);
  await context.inMemoryCache.set(cacheKey, metadata, { useSecondaryCache: true });

  return metadata;
}
```

**Cache invalidation:** when a mutation changes data that is cached, delete the entry immediately so the next invocation fetches fresh data:

```javascript
async function updateObjectDefinition(context, objectName, changes) {
  await context.metadataClient.updateObjectDefinition(objectName, changes);

  // Invalidate stale cache entry
  await context.inMemoryCache.delete(`METADATA_${objectName}`, { useSecondaryCache: true });
}
```

**When NOT to use secondary cache:**

- Data that changes frequently (job statuses, resource availability)
- Per-user or per-tenant data where key collisions across tenants are possible
- Data written by other functions or external systems that don't manage the same cache keys

### Pattern: GeoService — Geocoding and Distance Matrix

`context.geoService` wraps the Skedulo Geo API. Each call counts against `maxConcurrentRequests` (the non-GraphQL concurrency limit — default 5). Batch operations where possible to stay within this limit.

**Address suggestions (geocoding):**

```javascript
// Resolve a single address to lat/lng
const results = await context.geoService.getAddressSuggestions({
  input: '123 Main St, Sydney NSW'
}, 1);  // maxResults = 1

if (!results || results.length === 0) {
  context.logger.warn('No geocoding result for address');
  return null;
}

const { geometry, formattedAddress } = results[0];
// geometry: { lat: number, lng: number }
// formattedAddress: string
```

**Distance matrix (travel times between multiple points):**

```javascript
// Calculate travel times from multiple origins to multiple destinations
// Each call counts as 1 non-GraphQL API call against maxConcurrentRequests
const matrix = await context.geoService.getDistanceMatrix(
  origins,      // LatLng[]
  destinations  // LatLng[]
);

// Look up a specific origin → destination pair
const key = context.geoService.createKey(origins[0], destinations[0]);
const entry = matrix.get(key);
// entry: { status: 'OK' | 'NO_ROUTE', duration?: { durationInSeconds }, distance?: { distanceInMeters } }

if (entry?.status === 'OK') {
  const minutes = Math.round(entry.duration.durationInSeconds / 60);
}
```

**Batch geocoding with concurrency control:**

Geocoding is a non-GraphQL call — it counts against `maxConcurrentRequests` (default 5). Process addresses in chunks to stay within the limit:

```javascript
import chunk from 'lodash/chunk';

async function geocodeAddresses(context, addresses) {
  const results = [];
  // maxConcurrentRequests is not exposed on context — hardcode to match the default (5)
  // or align with whatever limit was set in ExecutionContext.fromContext({ limits: { maxConcurrentRequests } })
  const CHUNK_SIZE = 5;

  for (const batch of chunk(addresses, CHUNK_SIZE)) {
    const resolved = await Promise.all(
      batch.map(async (address) => {
        const suggestions = await context.geoService.getAddressSuggestions(
          { input: address }, 1
        );
        return suggestions?.[0] ?? null;
      })
    );
    results.push(...resolved);
  }

  return results;
}
```

**Timezone lookup:**

```javascript
const timezone = await context.geoService.getTimezone({
  location: [lat, lng],   // [number, number]
  timestamp: Math.floor(Date.now() / 1000)  // Unix timestamp (seconds)
});
// Returns IANA timezone string e.g. 'Australia/Sydney'
```

> Cache geocoded results with `context.inMemoryCache` to avoid re-geocoding the same address in subsequent invocations. See [Caching Expensive Operations](#pattern-caching-expensive-operations).

### Checklist: API Call Budget

Before shipping a function, account for every API call it makes:

```text
[ ] Used queryBatch for multiple independent reads at function start
[ ] Used mutateBatch for multiple independent writes
[ ] Used GraphBatch / UniqueGraphBatch for large dataset processing
[ ] Set readOnly: true on all query builders that don't precede a mutation
[ ] withFields lists only fields actually used in logic
[ ] Cursor pagination used for result sets that may exceed ~1 000 records
[ ] Expensive repeated lookups (metadata, config) use inMemoryCache
[ ] ExecutionContext limits overridden if function legitimately needs > 50 calls
[ ] getExecutionMetrics() logged at finish during development/testing
```

---

### PSF Patterns

PSF sits on top of PSS and provides a typed data service layer (`DataService<T>`), recurring date generation, and template processing. The key difference: PSF uses `initExecutionContext` / `getExecutionContext` instead of passing `context` around explicitly.

`service.query()` auto-paginates using cursor pagination (page size 200, same as PSS `INITIAL_GRAPHQL_PAGE_LIMIT`) — the same pagination limits apply. PSF calls count against the shared `ExecutionContext` `totalCalls` budget. See [Understanding Execution Limits](#understanding-execution-limits).

### PSF Execution Context Initialization

PSF maintains a module-level singleton context. Initialize it once at the start of your handler — all `DataService` instances share it automatically:

```typescript
import { initExecutionContext } from '@skedulo/pulse-solutions-framework'

// In your handler, before calling any service
initExecutionContext(
  skedContext.apiServer,
  skedContext.apiToken,
  'my-project',
  'my-function'
)
```

### Pattern: Typed Data Service with Change Detection

The PSF `DataService<T>` builds and executes GraphQL automatically from object definitions. Providing `sourceRecords` enables **change detection** — only modified fields are sent in the mutation, reducing payload size and avoiding unnecessary updates:

```typescript
import { createBaseService, Operator } from '@skedulo/pulse-solutions-framework'
import * as objectDefinitions from './object-definitions'
import { Jobs } from './models'

const jobsService = createBaseService<Jobs>({
  objectName: 'Jobs',
  objectDefinitions
})

// 1. Query — automatically paginates until all records are fetched
const { jobs } = await jobsService.query([
  {
    conditions: [
      ['JobStatus', Operator.IN, ['Pending Allocation', 'Queued']],
      ['Start', Operator.GREATER_OR_EQUAL, '2025-01-01T00:00:00.000Z']
    ],
    orderBy: 'Start ASC'
  }
])

// 2. Modify
const updated = jobs.map(job => ({ ...job, JobStatus: 'Dispatched' }))

// 3. Save with sourceRecords — only changed fields (JobStatus) are sent
await jobsService.save(updated, {
  sourceRecords: jobs,         // enables diff — skips records with no changes
  bulkOperation: true,         // adds X-Skedulo-Bulk-Operation header
  suppressChangeEvents: true   // disables change history tracking
})
```

**Important internal limits from PSF source:**

- `MAX_MUTATION_SIZE = 500` — save automatically chunks records into batches of 500; if a chunk fails the batch throws and already-saved chunks are **not** rolled back — wrap in `try/catch` and implement compensating logic if atomicity is required
- `INITIAL_GRAPHQL_PAGE_LIMIT = 200` — query auto-paginates using cursor until all records retrieved
- `DEFAULT_SUB_QUERY_LIMIT = 20` — related list queries default to 20 records unless overridden
- `parentMaxLevel = 2`, `childrenMaxLevel = 1` — relationship traversal depth (configurable in `ServiceSetting`)

### Pattern: Related List Save (Parent + Children in One Call)

PSF `save` handles parent-child relationships in a single call. It resolves the parent UID and wires it into child records automatically:

```typescript
import { Jobs, JobTags } from './models'

const newJob: Partial<Jobs> = {
  Name: 'Installation',
  JobStatus: 'Pending Allocation',
  Duration: 60,
  RegionId: 'region-abc',
  // Include child records inline
  JobTags: [
    { TagId: 'tag-1', Required: true } as JobTags,
    { TagId: 'tag-2', Required: false } as JobTags
  ]
}

// PSF builds one mutation that inserts the job and both tags,
// automatically linking tags to the new job UID
const results = await jobsService.save([newJob as Jobs])
// results[0].schema contains the alias→UID map for all inserted records
```

### Pattern: Period Overlap Query

Use `Operator.PERIOD` with a two-field tuple to find records whose time window overlaps a given range. PSF compiles this into `(Start <= rangeEnd AND End >= rangeStart)`:

```typescript
import { Operator } from '@skedulo/pulse-solutions-framework'

const rangeStart = '2025-06-01T00:00:00.000Z'
const rangeEnd   = '2025-06-30T23:59:59.999Z'

const { jobAllocations } = await jobAllocationsService.query([
  // Main object filter
  {
    conditions: [
      ['Status', Operator.NOT_IN, ['Deleted', 'Declined']]
    ]
  },
  // Related list with period filter
  {
    relatedList: 'JobAllocations',
    conditions: [
      [['Start', 'End'], Operator.PERIOD, [rangeStart, rangeEnd]]
    ]
  }
])

// PERIOD_INCLUDE_NULL — also matches records where Start or End is null
const { activities } = await activitiesService.query([
  {
    conditions: [
      [['Start', 'End'], Operator.PERIOD_INCLUDE_NULL, [rangeStart, rangeEnd]]
    ]
  }
])
```

### Pattern: Recurring Date Generation

Use PSF `createRecurringService` to generate occurrence dates from a recurrence rule — useful for scheduling, availability windows, or template-based job creation:

```typescript
import {
  createRecurringService,
  RepeatMode,
  EndMode
} from '@skedulo/pulse-solutions-framework'

const recurringService = createRecurringService()

// Weekly Mon/Wed/Fri for 12 occurrences
const dates = recurringService.generateDates({
  startDate: '2025-07-01',
  timezoneSidId: 'America/New_York',
  repeatMode: RepeatMode.Weekly,
  every: 1,
  endMode: EndMode.After,
  endAfterNumberOccurrences: 12,
  repeatOnWeekdays: ['mon', 'wed', 'fri']
})

// Create jobs from the generated dates
const jobs = dates.map(date => ({
  Name: `Recurring Visit — ${date}`,
  JobStatus: 'Pending Allocation',
  Start: `${date}T09:00:00.000Z`,
  Duration: 60,
  RegionId: 'region-abc'
}))

await jobsService.save(jobs)
```

### Pattern: Job Template Application

Use `createJobTemplateService` to apply a configuration template to a job. PSF fetches the template from the Skedulo platform and fills in Duration (computing End), JobTasks with sequence numbers, and tag requirements:

```typescript
import { createJobTemplateService, initExecutionContext } from '@skedulo/pulse-solutions-framework'
import { jobsService } from './services/jobs-service'

initExecutionContext(skedContext.apiServer, skedContext.apiToken, 'my-project', 'job-creator')

const jobTemplateService = createJobTemplateService()

const baseJob = {
  Name: 'Home Visit',
  Start: '2025-07-15T09:00:00.000Z',
  Timezone: 'America/Chicago',
  RegionId: 'region-abc',
  AccountId: 'account-xyz'
}

// Single resource requirement mode — sets Quantity and JobTags
const job = await jobTemplateService.generateJobByTemplate(
  baseJob,
  'HomeVisitTemplate',
  false
)
// job.End calculated from template Duration
// job.JobTasks populated with Seq numbers
// job.Quantity and job.JobTags set from template requirements

await jobsService.save([job])
```

### PSF Pattern: Select Only the Fields You Need

By default PSF fetches all fields defined in the object definition. Use `overriddenFields` in the `QueryModel` to restrict the response to only what the function needs, reducing payload size and query time:

```typescript
// Good — only fetch fields the function actually uses
const { jobs } = await jobsService.query([
  {
    conditions: [['JobStatus', Operator.EQUAL, 'Queued']],
    overriddenFields: 'UID JobStatus Start RegionId'   // raw GraphQL field string
  }
])

// Also mark the query read-only when you are not mutating
const { jobs } = await jobsService.query(
  [{ conditions: [['JobStatus', Operator.EQUAL, 'Queued']], overriddenFields: 'UID JobStatus Start' }],
  { readOnly: true }
)
```

`overriddenFields` replaces the full field selection generated from the object definition — specify only the fields your logic requires. This is equivalent to calling `withFields([...])` on a PSS `QueryBuilder`.

### PSF Pattern: Raw EQL Condition

When PSF operators don't cover a complex condition, pass raw EQL through `Operator.CUSTOM`:

```typescript
const { contacts } = await contactsService.query([
  {
    conditions: [
      // Any raw EQL string — PSF passes it through verbatim
      ['_filter', Operator.CUSTOM, "AccountId != null AND Email != null AND Email != ''"]
    ]
  }
])
```

### PSF vs PSS Decision Guide

Use this to decide which library's API to call for a given operation. Both libraries share the same `ExecutionContext` call budget — PSF calls count against `totalCalls` just like PSS calls.

| Operation | PSS (`ExecutionContext`) | PSF (`createBaseService`) |
| --------- | ----------------------- | ------------------------- |
| Query with typed model + auto-pagination | — | `service.query(queryModels)` |
| Query with selected fields only | `queryBuilder.withFields([...])` | `QueryModel.overriddenFields` |
| Query with full builder control | `context.newQueryBuilder()` | `service.newQueryBuilder(queryModels)` |
| Mutation with change detection | — | `service.save(records, { sourceRecords })` |
| Mutation with full builder control | `context.graphqlService.mutate()` | — |
| Batch N queries in 1 API call | `graphqlService.queryBatch()` | — |
| Batch N mutations in 1 API call | `graphqlService.mutateBatch()` | — |
| Large dataset processing | `GraphBatch` / `UniqueGraphBatch` | — |
| Save parent + children in one call | — | `service.save([{ ...parent, children: [...] }])` |
| Period overlap filter | — | `Operator.PERIOD` / `PERIOD_INCLUDE_NULL` |
| Recurring date generation | — | `createRecurringService()` |
| Apply job template | — | `createJobTemplateService()` |
| Metadata, vocabulary, geo, notifications | `context.*Client` | — |
