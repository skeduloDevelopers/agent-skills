# @skedulo/pulse-solutions-framework Reference

A lower-level TypeScript framework for building a typed, reusable data service layer across connected functions. It wraps `@skedulo/pulse-solution-services` and provides three modules: **Data Service**, **Recurring Service**, and **Template Service**.

## When to Use Each Library

| Situation | Use |
| --------- | --- |
| Writing a function that queries/mutates Skedulo data directly | `@skedulo/pulse-solution-services` (`ExecutionContext`, `QueryBuilder`) |
| Building a shared service layer used across many functions (the `@cx` pattern) | `@skedulo/pulse-solutions-framework` (`createBaseService`, `DataService`) |
| Generating recurring dates (daily/weekly/monthly/yearly patterns) | `@skedulo/pulse-solutions-framework` (`createRecurringService`) |
| Applying configuration templates to Skedulo objects | `@skedulo/pulse-solutions-framework` (`createTemplateService`, `createJobTemplateService`) |

Both libraries are often used together — `pulse-solutions-framework` builds the service layer on top of the `ExecutionContext` from `pulse-solution-services`.

---

## Data Service

### Object Definitions

Every Skedulo object needs a definition that tells the service which fields exist, their types, and their relationships. Without a definition, fields are silently omitted or mistyped.

```typescript
import { createObjectDefinition, MappingType, ObjectDefinition } from '@skedulo/pulse-solutions-framework'

export const JobsDefinition: ObjectDefinition = createObjectDefinition({
  objectName: 'Jobs',
  fieldConfigs: [
    { fieldName: 'UID' },                                                    // string (default)
    { fieldName: 'Name', readonly: true },
    { fieldName: 'JobStatus' },
    { fieldName: 'RegionId' },
    { fieldName: 'Duration',    mappingType: MappingType.number },
    { fieldName: 'Start',       mappingType: MappingType.datetime },
    { fieldName: 'End',         mappingType: MappingType.datetime },
    { fieldName: 'Locked',      mappingType: MappingType.boolean },
    // Parent relationship
    { fieldName: 'Region',         mappingType: MappingType.reference,   referenceObject: 'Regions' },
    // Child relationship
    { fieldName: 'JobAllocations', mappingType: MappingType.relatedList, referenceObject: 'JobAllocations', parentField: 'Job' },
    { fieldName: 'JobTags',        mappingType: MappingType.relatedList, referenceObject: 'JobTags',        parentField: 'Job' }
  ]
})
```

### `MappingType` Reference

| Type                      | Usage                                           |
| ------------------------- | ----------------------------------------------- |
| `MappingType.string`      | Plain string fields (default when omitted)      |
| `MappingType.number`      | Numeric fields (Duration, counts, coordinates)  |
| `MappingType.date`        | Date-only fields (YYYY-MM-DD)                   |
| `MappingType.datetime`    | ISO datetime fields (Start, End, CreatedDate)   |
| `MappingType.boolean`     | Boolean fields (Locked, IsActive, IsVirtual)    |
| `MappingType.reference`   | Parent relationship (Region, Account)           |
| `MappingType.relatedList` | Child relationship (JobAllocations, JobTags)    |

### Creating a Service

```typescript
import { createBaseService, BaseModel } from '@skedulo/pulse-solutions-framework'
import * as objectDefinitions from './object-definitions'

interface Jobs extends BaseModel {
  JobStatus: string
  Start?: string
  End?: string
  Duration: number
  RegionId: string
}

const jobsService = createBaseService<Jobs>({
  objectName: 'Jobs',
  objectDefinitions   // must include all definitions needed for relationships
})
```

### `DataService<T>` Interface

```typescript
interface DataService<T extends BaseModel> {
  newQueryBuilder(queryModels: QueryModel[]): GraphQLQueryBuilder
  query(queryModels: QueryModel[], options?: QueryOptions): Promise<GetListResponse<T>>
  save(objects: T[], options?: SaveOptions<T>): Promise<SaveResult[]>
}
```

### Querying

```typescript
import { Operator } from '@skedulo/pulse-solutions-framework'

// Simple query
const result = await jobsService.query([
  {
    conditions: [
      ['JobStatus', Operator.NOT_IN, ['Cancelled', 'Complete']],
      ['Start', Operator.GREATER_OR_EQUAL, '2025-01-01T00:00:00.000Z']
    ],
    orderBy: 'Start ASC'
  }
])
const jobs = result.jobs   // key is camelCase plural of objectName

// Related list query
const result = await jobsService.query([
  {
    conditions: [['JobStatus', Operator.EQUAL, 'Queued']]
  },
  {
    relatedList: 'JobAllocations',
    conditions: [['Status', Operator.NOT_IN, ['Deleted', 'Declined']]]
  }
])

// Period overlap query — use tuple [startField, endField] with Operator.PERIOD
const result = await jobsService.query([
  {
    conditions: [
      [['Start', 'End'], Operator.PERIOD, ['2025-01-01T00:00:00.000Z', '2025-12-31T23:59:59.999Z']]
    ]
  }
])

// Custom logic (reference conditions by 1-based index)
const result = await jobsService.query([
  {
    conditions: [
      ['Start', Operator.GREATER_OR_EQUAL, startDate],
      ['End', Operator.LESS_OR_EQUAL, endDate],
      ['JobStatus', Operator.IN, ['Pending Allocation', 'Queued']]
    ],
    customLogic: '(1 AND 2) AND 3'
  }
])

// Raw EQL condition
const result = await jobsService.query([
  {
    conditions: [
      ['filter', Operator.CUSTOM, "ContactId != null AND ContactId != ''"]
    ]
  }
])

// Read-only optimization
const result = await jobsService.query(queryModels, { readOnly: true })
```

### Supported Operators

| Operator                  | GraphQL Equivalent | Description                                        |
| ------------------------- | ------------------ | -------------------------------------------------- |
| `EQUAL`                   | `==`               | Exact match                                        |
| `NOT_EQUAL`               | `!=`               | Not equal                                          |
| `IN`                      | `IN`               | Value in array                                     |
| `NOT_IN`                  | `NOTIN`            | Value not in array                                 |
| `GREATER`                 | `>`                | Greater than                                       |
| `GREATER_OR_EQUAL`        | `>=`               | Greater than or equal                              |
| `LESS`                    | `<`                | Less than                                          |
| `LESS_OR_EQUAL`           | `<=`               | Less than or equal                                 |
| `INCLUDES`                | `INCLUDES`         | Picklist value included                            |
| `EXCLUDES`                | `EXCLUDES`         | Picklist value excluded                            |
| `INCLUDES_ALL`            | Custom             | All values included                                |
| `INCLUDES_ANY`            | Custom             | Any value included                                 |
| `EXCLUDES_ALL`            | Custom             | All values excluded                                |
| `PERIOD`                  | Custom             | Date range overlap — use tuple `[startF, endF]`    |
| `PERIOD_INCLUDE_NULL`     | Custom             | Date range overlap, includes null period fields    |
| `CUSTOM`                  | Custom             | Raw EQL expression passed through as-is            |

### Saving Records

```typescript
// Insert (no UID)
await jobsService.save([
  { Name: 'New Job', JobStatus: 'Pending Allocation', Duration: 60, RegionId: 'region-123' }
])

// Update (UID required — only modified fields are sent if sourceRecords provided)
await jobsService.save(
  [{ UID: 'job-abc', JobStatus: 'Complete' }],
  { sourceRecords: originalJobs }     // enables change detection — only diffs are sent
)

// Delete
await jobsService.save([{ UID: 'job-abc', _IsDeleted: true }])

// Bulk operation + suppress change events (for large datasets)
await jobsService.save(records, {
  bulkOperation: true,            // adds X-Skedulo-Bulk-Operation header
  suppressChangeEvents: true      // disables change history tracking
})
```

### `QueryModel` Structure

```typescript
interface QueryModel {
  conditions?: [string | string[], Operator, any][]
  customLogic?: string        // e.g. "(1 AND 2) OR 3" — references conditions by 1-based index
  orderBy?: string            // e.g. "Start ASC"
  limit?: number
  relatedList?: string        // name of the related list field from the parent definition
  overriddenFields?: string   // raw GraphQL field selection string, overrides definition
}
```

### Service Factory Pattern

For projects where many functions share access to the same Skedulo objects, build a service factory with a singleton cache:

```typescript
import { BaseModel } from '@skedulo/pulse-solutions-framework'
import { camelCase } from 'lodash'
import { createDataService } from './data-service'
import * as objectServices from './object-services'

const engineContext = new Map<string, any>()

const resolveDataService = <T extends BaseModel>(objectName: string) => {
  if (!engineContext.has(objectName)) {
    const key = `${camelCase(objectName)}Service` as keyof typeof objectServices
    const service = objectServices[key] ?? createDataService<T>(objectName)
    engineContext.set(objectName, service)
  }
  return engineContext.get(objectName)
}

export { resolveDataService }
```

### Specialized Services

Extend `DataService<T>` with domain-specific methods:

```typescript
import { DataService, Operator } from '@skedulo/pulse-solutions-framework'
import { Regions } from '../models'
import { createDataService } from '../data-service'

type RegionsService = DataService<Regions> & {
  fetchByIds: (ids: string[]) => Promise<Regions[]>
}

const createRegionsService = (): RegionsService => {
  const base = createDataService<Regions>('Regions')

  const fetchByIds = async (ids: string[]): Promise<Regions[]> => {
    if (!ids.length) return []
    const { regions } = await base.query([
      { conditions: [['UID', Operator.IN, ids]] }
    ])
    return regions ?? []
  }

  return { ...base, fetchByIds }
}

export const regionsService = createRegionsService()
export type { RegionsService }
```

Export every service from `object-services/index.ts` so the factory can discover them by convention.

---

## Recurring Service

Generates recurring dates from a pattern definition. Supports daily, weekly, monthly, and yearly recurrence with timezone handling.

```typescript
import { createRecurringService, RepeatMode, EndMode } from '@skedulo/pulse-solutions-framework'

const recurringService = createRecurringService()

// Generate 5 daily dates starting 2025-01-01
const dates = recurringService.generateDates({
  startDate: '2025-01-01',
  timezoneSidId: 'America/New_York',
  repeatMode: RepeatMode.Daily,
  every: 1,
  endMode: EndMode.After,
  endAfterNumberOccurrences: 5
})
// → ['2025-01-01', '2025-01-02', '2025-01-03', '2025-01-04', '2025-01-05']

// Weekly on Mon/Wed/Fri, end by date
const dates = recurringService.generateDates({
  startDate: '2025-01-06',
  timezoneSidId: 'UTC',
  repeatMode: RepeatMode.Weekly,
  every: 1,
  endMode: EndMode.On,
  endOn: '2025-01-31',
  repeatOnWeekdays: ['mon', 'wed', 'fri']
})

// Monthly on the 15th, skip a specific date
const dates = recurringService.generateDates({
  startDate: '2025-01-15',
  timezoneSidId: 'UTC',
  repeatMode: RepeatMode.Monthly,
  every: 1,
  endMode: EndMode.After,
  endAfterNumberOccurrences: 3,
  repeatOnDayOfMonth: 15,
  skippedDates: ['2025-02-15']
})
// → ['2025-01-15', '2025-03-15', '2025-04-15']
```

### `RecurringPattern` Fields

| Field                        | Type         | Description                                        |
| ---------------------------- | ------------ | -------------------------------------------------- |
| `startDate`                  | `string`     | ISO date `YYYY-MM-DD`                              |
| `timezoneSidId`              | `string`     | Timezone e.g. `"UTC"`, `"America/New_York"`        |
| `repeatMode`                 | `RepeatMode` | `Daily`, `Weekly`, `Monthly`, `Yearly`             |
| `every`                      | `number`     | Interval (every N days/weeks/months/years)         |
| `endMode`                    | `EndMode`    | `After` (N occurrences) or `On` (specific date)    |
| `endAfterNumberOccurrences`  | `number`     | Used when `endMode === EndMode.After`              |
| `endOn`                      | `string`     | ISO date used when `endMode === EndMode.On`        |
| `repeatOnWeekdays`           | `string[]`   | e.g. `['mon', 'wed', 'fri']` for weekly mode       |
| `repeatOnDayOfMonth`         | `number`     | Day of month for monthly/yearly mode               |
| `skippedDates`               | `string[]`   | Exception dates to skip (ISO date strings)         |
| `firstDayOfWeek`             | `number`     | `0` = Sunday, `1` = Monday (default)               |

---

## Template Service

Applies configuration templates to Skedulo objects, supporting custom field handlers and caching.

### Basic Template Service

```typescript
import { createTemplateService } from '@skedulo/pulse-solutions-framework'

const templateService = createTemplateService()

// Register custom field handlers for an object type
templateService.registerObjectFieldHandlers('Jobs', {
  priority: (fieldValue, targetObject) => {
    targetObject.Priority = fieldValue.toUpperCase()
  }
})

// Create an object-specific engine and apply a template
const engine = templateService.createObjectTemplateEngine('Jobs')
const result = await engine.applyObjectTemplate(job, 'InstallationTemplate')
```

### Job Template Service

Extends the base service with job-specific logic: duration → end time calculation, task generation with sequence numbers, resource requirements, and tag weighting.

```typescript
import { createJobTemplateService } from '@skedulo/pulse-solutions-framework'

const jobTemplateService = createJobTemplateService()

// Generate a job from a template (single resource requirement mode)
const job = {
  Name: 'Install Job',
  Start: '2025-01-15T09:00:00.000Z',
  Timezone: 'UTC'
}

const result = await jobTemplateService.generateJobByTemplate(
  job,
  'InstallationTemplate',
  false   // multipleRequirementEnabled: false = single mode (sets Quantity + JobTags)
          //                              true  = multiple mode  (sets ResourceRequirements[])
)
// result.End is automatically calculated from template Duration
// result.JobTasks includes generated tasks with Seq numbers
```

## See Also

- `@cx` shared library pattern: [../../../connected-function-developer/references/cx-library.md](../../../connected-function-developer/references/cx-library.md)
- `@skedulo/pulse-solution-services` (higher-level `ExecutionContext`, `QueryBuilder`, batch processing): the main `skedulo-api-developer` SKILL.md
