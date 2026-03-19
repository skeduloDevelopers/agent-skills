# Quick Reference Guide

Fast lookup for common operations and troubleshooting.

## Common Operations

### Initialize Context

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "my-project",
  userAgent: "my-function"
});
```

### Query Records

```javascript
const result = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "query" })
  .withFields(["UID", "Name"])
  .withFilter("JobStatus = 'Pending'")
  .withLimit(100)
  .execute();
```

### Insert Records

```javascript
await context.graphqlService.mutate({
  objectName: "Jobs",
  operation: GraphqlOperations.INSERT,
  operationName: "insert",
  records: [{ Name: "New Job", Start: "2025-11-01T09:00:00Z" }]
});
```

### Update Records

```javascript
await context.graphqlService.mutate({
  objectName: "Jobs",
  operation: GraphqlOperations.UPDATE,
  operationName: "update",
  records: [{ UID: jobId, JobStatus: "Complete" }]
});
```

### Delete Records

```javascript
await context.graphqlService.mutate({
  objectName: "Jobs",
  operation: GraphqlOperations.DELETE,
  operationName: "delete",
  records: [{ UID: jobId }]
});
```

### Upsert Records

```javascript
await context.graphqlService.upsert({
  objectName: "Contacts",
  operationName: "upsert",
  externalIdField: "ExternalId__c",
  records: [{ ExternalId__c: "EXT-123", Name: "John Smith" }]
});
```

### Query with Pagination

```javascript
const pages = await context.graphqlService.queryByPages(queryBuilder, {
  pageSize: 100,
  maxPages: 10,
  strategy: PaginationStrategy.CURSOR
});
```

### Get Config Value

```javascript
const apiKey = context.configHelper.getString('API_KEY');
const timeout = context.configHelper.getNumber('TIMEOUT');
const config = context.configHelper.getJson('CONFIG');
```

### Acquire Lock

```javascript
const acquired = await context.lockService.acquireLock({
  name: 'LOCK_NAME',
  ttl: 5 * 60 * 1000
});
```

### Send Notification

```javascript
await context.mobileNotificationClient.send({
  resourceIds: ["resource-id"],
  title: "Alert",
  body: "Message text"
});
```

### Calculate Distance

```javascript
const matrix = await context.geoService.getDistanceMatrix(
  [{ lat: 37.7749, lng: -122.4194 }],
  [{ lat: 37.8044, lng: -122.2712 }]
);
```

## Performance Tips

### Use Cursor Pagination for Large Datasets

```javascript
// Good for 1000+ records
const results = await context.graphqlService.queryByPages(queryBuilder, {
  strategy: PaginationStrategy.CURSOR,
  pageSize: 100
});
```

### Batch Multiple Queries

```javascript
// Execute in parallel
const [jobs, resources] = await Promise.all([
  context.graphqlService.query(jobQuery),
  context.graphqlService.query(resourceQuery)
]);
```

### Select Only Needed Fields

```javascript
// Good: specific fields
.withFields(["UID", "Name", "Start"])

// Avoid: all fields
.withFields(["*"])
```

### Cache Expensive Operations

```javascript
const cached = await context.inMemoryCache.get("KEY", {
  useSecondaryCache: true
});

if (!cached) {
  const data = await expensiveOperation();
  await context.inMemoryCache.set("KEY", data, {
    useSecondaryCache: true
  });
}
```

### Use Batch Processing for Bulk Operations

```javascript
const batch = new MyBatch(context, {
  batchSize: 100,
  strategy: PaginationStrategy.CURSOR
});
await batch.run();
```

## Common Filters

### Date Range

```javascript
.withFilter(`Start >= '${startDate}' AND Start <= '${endDate}'`)
```

### Status Filter

```javascript
.withFilter("JobStatus = 'Pending'")
```

### Multiple Conditions

```javascript
.withFilter("JobStatus = 'Pending' AND Region.Name = 'North'")
```

### IN Clause

```javascript
.withFilter(`UID IN ('${id1}', '${id2}', '${id3}')`)
```

### NOT NULL

```javascript
.withFilter("Region.UID != null")
```

### Text Search

```javascript
.withFilter("Name LIKE '%Emergency%'")
```

## Error Handling

### Basic Try-Catch

```javascript
try {
  await operation();
} catch (error) {
  context.logger.error("Operation failed", { error: error.message });
  throw error;
}
```

### Retry on Failure

```javascript
async function retry(fn, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === attempts - 1) throw error;
      await new Promise(r => setTimeout(r, 1000 * (i + 1)));
    }
  }
}
```

### Graceful Degradation

```javascript
try {
  return await primaryOperation();
} catch (error) {
  context.logger.warn("Primary failed, using fallback", { error });
  return await fallbackOperation();
}
```

## Troubleshooting

### Issue: Execution Limit Exceeded

**Problem:** Function hits API call limit

**Solution:** Increase limits or optimize queries

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "my-project",
  userAgent: "my-function",
  limits: {
    totalCalls: 100,
    maxConcurrentRequests: 10
  }
});
```

### Issue: Query Timeout

**Problem:** Query takes too long

**Solutions:**
1. Add more specific filters
2. Reduce page size
3. Use cursor pagination
4. Limit fields selected

```javascript
// Add specific filter
.withFilter("CreatedDate > '2025-01-01'")

// Reduce page size
const pages = await context.graphqlService.queryByPages(queryBuilder, {
  pageSize: 50  // Smaller batches
});
```

### Issue: Lock Already Held

**Problem:** Cannot acquire lock

**Solutions:**
1. Check if previous execution still running
2. Wait and retry
3. Reduce lock TTL
4. Release stale locks manually

```javascript
// Wait and retry
const acquired = await acquireLockWithRetry(context, 'LOCK_NAME', {
  maxRetries: 5,
  retryDelay: 2000
});
```

### Issue: Memory Exceeded

**Problem:** Processing too much data at once

**Solutions:**
1. Use smaller batch sizes
2. Process in chunks
3. Stream data instead of loading all

```javascript
// Smaller batches
const batch = new MyBatch(context, {
  batchSize: 25  // Reduced from 100
});
```

### Issue: GraphQL Error

**Problem:** Query returns error

**Common causes:**
1. Invalid filter syntax
2. Non-existent field
3. Wrong object name
4. Missing permissions

**Solution:** Check error message and validate query

```javascript
try {
  await context.graphqlService.query(queryBuilder);
} catch (error) {
  console.log("Error details:", error.message);
  // Check: field names, object names, filter syntax
}
```

### Issue: Cache Miss Rate High

**Problem:** Cache not effective

**Solutions:**
1. Increase cache TTL
2. Use secondary cache
3. Pre-warm cache
4. Check cache key consistency

```javascript
// Use secondary cache for persistence
await context.inMemoryCache.set("KEY", data, {
  useSecondaryCache: true  // Persists across executions
});
```

### Issue: Concurrent Modification

**Problem:** Records modified by multiple processes

**Solutions:**
1. Use locks
2. Check timestamps
3. Implement optimistic locking
4. Use unique batches

```javascript
// Use unique batch to prevent concurrent runs
class UniqueProcess extends UniqueGraphBatch {
  // Implementation
}
```

## Debugging Tips

### Log Execution Metrics

```javascript
const metrics = context.getExecutionMetrics();
console.log("API Calls:", metrics.totalCalls);
console.log("Execution Time:", metrics.executionTimeMs);
```

### Enable Detailed Logging

Set environment variables:
- `LOG_NAMESPACE=*` (log everything)
- `LOG_ENTRY_MAX_LENGTH=1000` (more detail)

### Log Query Results

```javascript
const result = await queryBuilder.execute();
context.logger.info("Query results", {
  count: result.records.length,
  hasMore: result.pageInfo?.hasNextPage
});
```

### Track Operation Timing

```javascript
const start = Date.now();
await operation();
const duration = Date.now() - start;
context.logger.info("Operation completed", { durationMs: duration });
```

## Best Practices Checklist

- [ ] Initialize context with meaningful requestSource and userAgent
- [ ] Set appropriate execution limits
- [ ] Use cursor pagination for large datasets
- [ ] Batch multiple independent queries with Promise.all
- [ ] Select only needed fields
- [ ] Apply filters to reduce data transfer
- [ ] Implement proper error handling
- [ ] Use locks for critical sections
- [ ] Cache expensive operations
- [ ] Log structured data for observability
- [ ] Use UniqueGraphBatch to prevent duplicate runs
- [ ] Validate data before mutations
- [ ] Release locks in finally blocks
- [ ] Monitor execution metrics
- [ ] Test with production data volumes
