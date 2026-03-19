# Advanced Patterns and Recipes

This file contains advanced patterns and complete recipes for common Skedulo development scenarios.

## Table of Contents

1. [Error Handling Patterns](#error-handling-patterns)
2. [Retry Mechanisms](#retry-mechanisms)
3. [Transaction Patterns](#transaction-patterns)
4. [Data Migration](#data-migration)
5. [Webhook Processing](#webhook-processing)
6. [Scheduled Job Patterns](#scheduled-job-patterns)
7. [Complex Queries](#complex-queries)
8. [Performance Optimization](#performance-optimization)

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

Retry lock acquisition with timeout:

```javascript
async function acquireLockWithRetry(context, lockName, options = {}) {
  const maxRetries = options.maxRetries || 5;
  const retryDelay = options.retryDelay || 2000;
  const ttl = options.ttl || 5 * 60 * 1000;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const acquired = await context.lockService.acquireLock({
      name: lockName,
      ttl
    });

    if (acquired) {
      return true;
    }

    if (attempt < maxRetries - 1) {
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }

  return false;
}

// Usage
const locked = await acquireLockWithRetry(context, 'SYNC_JOBS', {
  maxRetries: 5,
  retryDelay: 2000,
  ttl: 10 * 60 * 1000
});

if (!locked) {
  throw new Error('Could not acquire lock');
}
```

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

### Pattern: Two-Phase Commit

Validate before committing changes:

```javascript
async function updateJobsWithValidation(context, updates) {
  // Phase 1: Validate all updates
  const validationResults = [];
  
  for (const update of updates) {
    const job = await context.graphqlService.query(
      context.newQueryBuilder({ objectName: "Jobs", operationName: "getJob" })
        .withFields(["UID", "JobStatus", "Start"])
        .withFilter(`UID = '${update.UID}'`)
    );

    if (!job.records[0]) {
      validationResults.push({ uid: update.UID, valid: false, reason: "Job not found" });
      continue;
    }

    const isValid = validateUpdate(job.records[0], update);
    validationResults.push({ uid: update.UID, valid: isValid });
  }

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
      .withFields(["UID", "Name", "Description", "CreatedDate"])
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

Run cleanup operations on a schedule:

```javascript
import { UniqueGraphBatch } from "@skedulo/pulse-solution-services";

class DailyCleanup extends UniqueGraphBatch {
  protected async start() {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    return this.context
      .newQueryBuilder({ objectName: "Jobs", operationName: "fetchExpired" })
      .withFields(["UID", "Name", "JobStatus"])
      .withFilter(`JobStatus = 'Cancelled' AND CreatedDate < '${thirtyDaysAgo.toISOString()}'`);
  }

  protected async execute(records) {
    const uids = records.map(r => ({ UID: r.UID }));

    await this.context.graphqlService.mutate({
      objectName: "Jobs",
      operation: GraphqlOperations.DELETE,
      operationName: "deleteExpired",
      records: uids
    });

    this.context.logger.info(`Deleted ${records.length} expired jobs`);
  }
}

// Schedule to run daily
const cleanup = new DailyCleanup(context, {
  batchSize: 100,
  maxBatches: 20,
  lockTtl: 30 * 60 * 1000  // 30 minutes
});

await cleanup.run();
```

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

### Pattern: Parallel Processing with Concurrency Control

Process items in parallel with controlled concurrency:

```javascript
async function processJobsInParallel(context, jobIds, concurrency = 5) {
  const results = [];
  const queue = [...jobIds];

  async function worker() {
    while (queue.length > 0) {
      const jobId = queue.shift();
      if (!jobId) break;

      try {
        const result = await processJob(context, jobId);
        results.push({ jobId, success: true, result });
      } catch (error) {
        results.push({ jobId, success: false, error: error.message });
      }
    }
  }

  // Create worker pool
  const workers = Array(concurrency).fill(null).map(() => worker());
  await Promise.all(workers);

  return results;
}

async function processJob(context, jobId) {
  // Job processing logic
  const job = await context.graphqlService.query(
    context.newQueryBuilder({ objectName: "Jobs", operationName: "getJob" })
      .withFields(["UID", "Name", "JobStatus"])
      .withFilter(`UID = '${jobId}'`)
  );

  return job.records[0];
}
```

### Pattern: Caching Strategy

Implement multi-layer caching:

```javascript
class CachedMetadataService {
  constructor(context) {
    this.context = context;
    this.memoryCache = new Map();
  }

  async getMetadata(objectName) {
    // Check memory cache
    if (this.memoryCache.has(objectName)) {
      return this.memoryCache.get(objectName);
    }

    // Check persistent cache
    const cached = await this.context.inMemoryCache.get(
      `METADATA_${objectName}`,
      { useSecondaryCache: true }
    );

    if (cached) {
      this.memoryCache.set(objectName, cached);
      return cached;
    }

    // Fetch from API
    const metadata = await this.context.metadataClient.fetchObjectMetadata(objectName);

    // Store in caches
    this.memoryCache.set(objectName, metadata);
    await this.context.inMemoryCache.set(
      `METADATA_${objectName}`,
      metadata,
      { useSecondaryCache: true }
    );

    return metadata;
  }

  invalidateCache(objectName) {
    this.memoryCache.delete(objectName);
    // Note: Secondary cache has TTL and will expire automatically
  }
}

// Usage
const metadataService = new CachedMetadataService(context);
const jobMetadata = await metadataService.getMetadata('Jobs');
```

### Pattern: Bulk Operation Batching

Batch operations for better performance:

```javascript
class BulkOperationBatcher {
  constructor(context, options = {}) {
    this.context = context;
    this.batchSize = options.batchSize || 200;
    this.flushInterval = options.flushInterval || 5000;
    this.operations = {
      insert: [],
      update: [],
      delete: []
    };
    this.timer = null;
  }

  addInsert(record) {
    this.operations.insert.push(record);
    this.scheduleFlush();
  }

  addUpdate(record) {
    this.operations.update.push(record);
    this.scheduleFlush();
  }

  addDelete(uid) {
    this.operations.delete.push({ UID: uid });
    this.scheduleFlush();
  }

  scheduleFlush() {
    if (this.timer) return;
    
    this.timer = setTimeout(() => this.flush(), this.flushInterval);

    // Flush immediately if batch is full
    const totalOps = this.operations.insert.length + 
                     this.operations.update.length + 
                     this.operations.delete.length;
    
    if (totalOps >= this.batchSize) {
      this.flush();
    }
  }

  async flush() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    const ops = { ...this.operations };
    this.operations = { insert: [], update: [], delete: [] };

    const promises = [];

    if (ops.insert.length > 0) {
      promises.push(
        this.context.graphqlService.mutate({
          objectName: "Jobs",
          operation: GraphqlOperations.INSERT,
          operationName: "batchInsert",
          records: ops.insert
        })
      );
    }

    if (ops.update.length > 0) {
      promises.push(
        this.context.graphqlService.mutate({
          objectName: "Jobs",
          operation: GraphqlOperations.UPDATE,
          operationName: "batchUpdate",
          records: ops.update
        })
      );
    }

    if (ops.delete.length > 0) {
      promises.push(
        this.context.graphqlService.mutate({
          objectName: "Jobs",
          operation: GraphqlOperations.DELETE,
          operationName: "batchDelete",
          records: ops.delete
        })
      );
    }

    await Promise.all(promises);
  }
}

// Usage
const batcher = new BulkOperationBatcher(context, {
  batchSize: 200,
  flushInterval: 5000
});

// Queue operations
for (const job of jobs) {
  batcher.addUpdate({
    UID: job.UID,
    JobStatus: "Complete"
  });
}

// Ensure final flush
await batcher.flush();
```
