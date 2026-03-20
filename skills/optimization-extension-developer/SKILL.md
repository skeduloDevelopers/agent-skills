---
name: optimization-extension-developer
description: This skill enables Claude to build, modify, and deploy Skedulo Optimization Extensions. Optimization Extensions add custom business logic to the Pulse Platform optimization engine, allowing filtering of jobs/resources, applying constraints, and transforming optimization data.
displayName: Optimization Extensions
status: available
category: Backend
featured: false
pulseComponents:
  - Optimization Extensions
sdks:
  - "@skedulo/sdk-utilities"
  - "@skedulo/pulse-solution-services"
  - "@skedulo/optimization-manager-client"
filePatterns:
  - "src/functions/optimization-extensions/**/*.ts"
  - "sked.proj.json"
---

# Skedulo Optimization Extensions Skill

## What Are Optimization Extensions?

Optimization Extensions are Connected Functions that hook into Skedulo's optimization engine. They allow you to transform data before and after optimization runs without modifying the core platform.

**Key Benefits:**
- Add custom business logic to optimization runs
- Filter jobs or resources by specific criteria
- Apply custom constraints to the optimization engine
- Integrate external data sources
- Modify optimization behavior dynamically

## Core Concepts

### Extension Structure

Every optimization extension has this file structure:
```text
my-extension/
├── sked.proj.json       # Function configuration
├── state.json           # Metadata for CLI operations
├── package.json         # Node.js dependencies
├── tsconfig.json        # TypeScript configuration
├── src/
│   ├── handler.ts       # Main entry point
│   ├── routes.ts        # Route definitions
│   └── handlers/
│       ├── transformSchedule.ts      # Transformation logic
│       └── transformSchedule.test.ts # Unit tests
└── .env                 # Local config variables (not deployed)
```

### Key Interfaces

The `@skedulo/optimization-manager-client` package provides the core types:

```typescript
import {
  TransformerInput,
  TransformerOutput,
  createOptimizationRoutes
} from '@skedulo/optimization-manager-client';
```

**TransformerInput** - What you receive:
- `featureModel`: Input to optimization engine - modify to change how optimization runs
- `productData`: Used for result generation - read-only, pass through unchanged
- `plan`: Original unmodified data - read-only, never modify
- `configuration`: Contains `baseUrl` and `accessToken` for external API calls

**TransformerOutput** - What you return:
- Must include BOTH `productData` AND `featureModel`
- Never return only one of them
- Never return status/body wrapper unless it's an error case

### Data Structure Understanding

| Property | Purpose | Can Modify? |
|----------|---------|-------------|
| `featureModel` | Input to optimization engine | Yes - changes optimization behavior |
| `productData` | Used for result generation | No - read-only, pass through unchanged |
| `plan` | Original unmodified data | No - read-only reference |
| `configuration` | API credentials | No - use for external calls |

### featureModel Structure

The `featureModel` is the primary object you'll modify. Key properties include:

```typescript
interface FeatureModel {
  jobs: Job[];           // Jobs to be scheduled
  resources: Resource[]; // Resources (technicians) available
  activities: Activity[]; // Existing activities/appointments
  shifts: Shift[];       // Resource availability windows
  constraints: Constraint[]; // Scheduling constraints
  objectives: Objective[]; // Optimization objectives
}

interface Job {
  id: string;            // Unique identifier (may have _0 suffix)
  priority: number;      // Scheduling priority
  duration: number;      // Expected duration in minutes
  skills: string[];      // Required skills
  location: Location;    // Job location
  timeWindows: TimeWindow[]; // When job can be scheduled
  // Additional custom fields vary by tenant
}

interface Resource {
  id: string;            // Unique identifier
  name: string;          // Resource name
  skills: string[];      // Skills/certifications
  region: string;        // Assigned region
  // Additional custom fields vary by tenant
}
```

**Note:** The exact structure may vary. Always use the `graphql-schema` MCP server to explore the actual data model for your tenant.

### Job ID Extraction

The allocation id field includes a suffix (like `_0`) that needs to be stripped to get the actual job UID:

```typescript
// Extract job UID from allocation ID
const extractJobUID = (allocationId: string): string => {
  return allocationId.replace(/_\d+$/, '');
};

// Example: "abc123_0" -> "abc123"
```

## Development Workflow

### 1. Generate Boilerplate

Always use the Skedulo CLI to create the standard function scaffolding:

```bash
sked function generate -n [extension-name] -o src/functions/optimization-extensions
cd src/functions/optimization-extensions/[extension-name]
yarn add @skedulo/optimization-manager-client
yarn install
```

### 2. Configure Routes

Use `createOptimizationRoutes` to set up the standard optimization endpoints:

```typescript
// src/routes.ts
import { FunctionRoute } from "@skedulo/sdk-utilities";
import { createOptimizationRoutes } from "@skedulo/optimization-manager-client";
import { transformSchedule } from './handlers/transformSchedule';

export function getRoutes(): FunctionRoute[] {
  return createOptimizationRoutes(transformSchedule);
}
```

### 3. Implement Handler

Create the transformation handler:

```typescript
// src/handlers/transformSchedule.ts
import { TransformerInput, TransformerOutput } from '@skedulo/optimization-manager-client';

export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  try {
    // Load config at start (never inline or in loops)
    const configValue = await context.configVarClient.get('CONFIG_KEY');

    // Transform featureModel
    const modifiedFeatureModel = {
      ...input.featureModel,
      // Your transformations here
    };

    // Always return both
    return {
      productData: input.productData,
      featureModel: modifiedFeatureModel
    };
  } catch (error) {
    console.error('Error in transformation:', error);
    return {
      status: 500,
      body: { error: 'Transformation failed' }
    };
  }
};
```

### 4. Run Tests

```bash
yarn test
```

Build and test MUST succeed before declaring work complete.

### 5. Deploy

```bash
# Deploy the function
sked artifacts function upsert -f state.json
```

## Configuration Management

### Rules

- **NEVER** use hardcoded values (magic strings)
- **ALWAYS** use `context.configVarClient.get()` for configurable values
- Load config values once at start, not in loops
- Provide sensible defaults for optional configuration
- Validate configuration values before use

### Example Configuration

In `sked.proj.json`:
```json
{
  "type": "function",
  "version": "2",
  "name": "priority-filter-extension",
  "description": "Filters jobs by priority level",
  "runtime": "nodejs22.x",
  "settings": {
    "configVars": [
      {
        "name": "PRIORITY_THRESHOLD",
        "configType": "plain-text",
        "description": "Minimum priority level to include (1-5)",
        "default": "3"
      },
      {
        "name": "INCLUDE_UNASSIGNED",
        "configType": "plain-text",
        "description": "Whether to include jobs without priority",
        "default": "true"
      }
    ]
  }
}
```

### Loading Configuration

```typescript
export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  // Load all config at start
  const priorityThreshold = parseInt(
    await context.configVarClient.get('PRIORITY_THRESHOLD') || '3'
  );
  const includeUnassigned =
    (await context.configVarClient.get('INCLUDE_UNASSIGNED')) === 'true';

  // Now use these values throughout the function
  // ...
};
```

## Common Patterns

### Job Filtering

Filter jobs from optimization based on criteria:

```typescript
export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  try {
    const priorityThreshold = parseInt(
      await context.configVarClient.get('PRIORITY_THRESHOLD') || '3'
    );

    // Get job IDs to exclude
    const jobsToExclude = new Set<string>();

    for (const job of input.featureModel.jobs || []) {
      if (job.priority < priorityThreshold) {
        jobsToExclude.add(job.id);
      }
    }

    // Filter jobs from featureModel
    const modifiedFeatureModel = {
      ...input.featureModel,
      jobs: input.featureModel.jobs?.filter(
        job => !jobsToExclude.has(job.id)
      )
    };

    return {
      productData: input.productData,
      featureModel: modifiedFeatureModel
    };
  } catch (error) {
    console.error('Error filtering jobs:', error);
    return { status: 500, body: { error: 'Job filtering failed' } };
  }
};
```

### Resource Filtering

Filter resources based on attributes:

```typescript
export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  try {
    const requiredCertification =
      await context.configVarClient.get('REQUIRED_CERTIFICATION');

    // Build set of certified resource IDs
    const certifiedResourceIds = new Set<string>();

    for (const resource of input.featureModel.resources || []) {
      if (resource.certifications?.includes(requiredCertification)) {
        certifiedResourceIds.add(resource.id);
      }
    }

    // Filter resources
    const modifiedFeatureModel = {
      ...input.featureModel,
      resources: input.featureModel.resources?.filter(
        r => certifiedResourceIds.has(r.id)
      )
    };

    return {
      productData: input.productData,
      featureModel: modifiedFeatureModel
    };
  } catch (error) {
    console.error('Error filtering resources:', error);
    return { status: 500, body: { error: 'Resource filtering failed' } };
  }
};
```

### Efficient Filtering with Sets

Always use Set for lookups instead of Array.includes():

```typescript
// GOOD: O(1) lookup
const allowedIdSet = new Set(allowedIds);
const filtered = jobs.filter(j => allowedIdSet.has(j.id));

// BAD: O(n) lookup for each item
const filtered = jobs.filter(j => allowedIds.includes(j.id));
```

### External Data Access

When featureModel/productData doesn't have needed data, retrieve from Skedulo API:

```typescript
import { ExecutionContext } from '@skedulo/pulse-solution-services';

export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  try {
    // Initialize ExecutionContext from TransformerInput credentials
    const context = ExecutionContext.fromCredentials({
      baseUrl: input.configuration.baseUrl,
      accessToken: input.configuration.accessToken
    }, {
      requestSource: 'optimization-extension',
      userAgent: 'job-filter'
    });

    // Fetch additional data
    const result = await context
      .newQueryBuilder({
        objectName: 'Jobs',
        operationName: 'fetchJobDetails'
      })
      .withFields(['UID', 'Name', 'Priority', 'CustomField__c'])
      .withFilter(`UID IN ('${jobIds.join("','")}')`)
      .execute();

    // Use fetched data in transformation
    const jobDetailsMap = new Map(
      result.records.map(r => [r.UID, r])
    );

    // Continue with transformation using jobDetailsMap
    // ...

    return {
      productData: input.productData,
      featureModel: modifiedFeatureModel
    };
  } catch (error) {
    console.error('Error fetching external data:', error);
    return { status: 500, body: { error: 'External data fetch failed' } };
  }
};
```

**Important:** Always use the `graphql-schema` MCP server to understand the data model. Don't assume field names or object structures.

## Performance Best Practices

### Use Efficient Data Structures

```typescript
// Use Map for key-value lookups
const jobMap = new Map(jobs.map(j => [j.id, j]));
const job = jobMap.get(jobId); // O(1)

// Use Set for membership checks
const excludedIds = new Set(idsToExclude);
const isExcluded = excludedIds.has(id); // O(1)
```

### Filter in a Single Pass

```typescript
// GOOD: Single pass with multiple conditions
const filteredJobs = jobs.filter(job =>
  job.priority >= threshold &&
  job.status === 'Queued' &&
  !excludedIds.has(job.id)
);

// BAD: Multiple passes
const byPriority = jobs.filter(j => j.priority >= threshold);
const byStatus = byPriority.filter(j => j.status === 'Queued');
const final = byStatus.filter(j => !excludedIds.has(j.id));
```

### Load Config Once

```typescript
// GOOD: Load config at start
const threshold = await context.configVarClient.get('THRESHOLD');
for (const job of jobs) {
  if (job.priority < threshold) { /* ... */ }
}

// BAD: Load config in loop
for (const job of jobs) {
  const threshold = await context.configVarClient.get('THRESHOLD');
  if (job.priority < threshold) { /* ... */ }
}
```

### Pagination for Large Queries

When fetching external data, use pagination:

```typescript
const pageSize = 200;
let offset = 0;
const allRecords = [];

while (true) {
  const result = await context
    .newQueryBuilder({ objectName: 'Jobs', operationName: 'fetchJobs' })
    .withFields(['UID', 'Name'])
    .withLimit(pageSize)
    .withOffset(offset)
    .execute();

  allRecords.push(...result.records);

  if (result.records.length < pageSize) break;
  offset += pageSize;
}
```

## Error Handling

### Always Wrap in Try-Catch

```typescript
export const transformSchedule = async (
  input: TransformerInput
): Promise<TransformerOutput> => {
  try {
    // Your transformation logic
    return {
      productData: input.productData,
      featureModel: modifiedFeatureModel
    };
  } catch (error) {
    console.error('Transformation error:', error);
    return {
      status: 500,
      body: { error: 'Transformation failed', details: error.message }
    };
  }
};
```

### Validate Configuration

```typescript
const configValue = await context.configVarClient.get('REQUIRED_CONFIG');
if (!configValue) {
  console.error('Missing required configuration: REQUIRED_CONFIG');
  return {
    status: 500,
    body: { error: 'Configuration error: REQUIRED_CONFIG not set' }
  };
}
```

### Handle External Data Failures

```typescript
let externalData;
try {
  externalData = await fetchExternalData(context, ids);
} catch (error) {
  console.error('Failed to fetch external data:', error);
  // Decide: fail the optimization or continue without external data
  return {
    status: 500,
    body: { error: 'External data unavailable' }
  };
}
```

## Unit Testing

### Basic Test Structure

```typescript
// src/handlers/transformSchedule.test.ts
import { transformSchedule } from './transformSchedule';
import { TransformerInput } from '@skedulo/optimization-manager-client';

describe('transformSchedule', () => {
  const mockInput: TransformerInput = {
    featureModel: {
      jobs: [
        { id: 'job1', priority: 5 },
        { id: 'job2', priority: 2 },
        { id: 'job3', priority: 4 }
      ],
      resources: []
    },
    productData: {},
    plan: {},
    configuration: {
      baseUrl: 'https://api.skedulo.com',
      accessToken: 'test-token'
    }
  };

  it('should filter low priority jobs', async () => {
    const result = await transformSchedule(mockInput);

    expect(result.featureModel.jobs).toHaveLength(2);
    expect(result.featureModel.jobs.map(j => j.id)).toEqual(['job1', 'job3']);
  });

  it('should always return both featureModel and productData', async () => {
    const result = await transformSchedule(mockInput);

    expect(result).toHaveProperty('featureModel');
    expect(result).toHaveProperty('productData');
  });

  it('should handle empty job list', async () => {
    const emptyInput = {
      ...mockInput,
      featureModel: { ...mockInput.featureModel, jobs: [] }
    };

    const result = await transformSchedule(emptyInput);

    expect(result.featureModel.jobs).toEqual([]);
  });

  it('should return error on failure', async () => {
    // Mock a failure scenario
    const badInput = null as any;

    const result = await transformSchedule(badInput);

    expect(result).toHaveProperty('status', 500);
    expect(result).toHaveProperty('body');
  });
});
```

### Mocking Configuration

```typescript
jest.mock('./config', () => ({
  getConfig: jest.fn().mockResolvedValue({
    PRIORITY_THRESHOLD: '3',
    INCLUDE_UNASSIGNED: 'true'
  })
}));
```

## Common Issues

### "TransformerOutput incomplete"
**Solution:** Always return both `productData` AND `featureModel`, even if one is unchanged.

### "Configuration not found"
**Solution:** Add config vars to `sked.proj.json` and create `.env` for local testing.

### Inefficient filtering with large datasets
**Solution:** Use `Set` for lookups, filter in single pass, avoid nested loops.

### External data fetch timeout
**Solution:** Add pagination, limit fields requested, add timeout handling.

### featureModel vs productData confusion
**Solution:**
- Modify `featureModel` to change how optimization RUNS
- Modify `productData` to change what gets SAVED in results

## Deployment Checklist

Before deploying:
- [ ] Handler compiles without errors
- [ ] Unit tests passing
- [ ] Config variables defined in sked.proj.json
- [ ] All business logic uses config vars (no hardcoded values)
- [ ] Efficient data structures used (Map/Set)
- [ ] Comprehensive error handling in place
- [ ] Both featureModel and productData returned
- [ ] Logging added for debugging
- [ ] Description updated in sked.proj.json

## Resources

- Skedulo CLI: Run `sked function generate --help`
- Optimization client: `@skedulo/optimization-manager-client` npm package
- Solution services: `@skedulo/pulse-solution-services` for API access
- GraphQL schema: Use `graphql-schema` MCP server to explore data model
- Platform docs: https://docs.skedulo.com/skedulo-api/optimization/