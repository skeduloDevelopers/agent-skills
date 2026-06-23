# @cx Shared Library Reference

A pattern for structuring shared code across all connected functions in a Skedulo project. The `@cx` library lives at `src/cx/`, is symlinked into each function directory, and provides typed models, a service factory, object definitions, configuration management, and date utilities.

## Directory Structure

```text
src/cx/
├── index.ts                          # Barrel export (exports all modules)
├── constants/
│   ├── index.ts                      # Barrel export
│   ├── types.ts                      # Domain enums (statuses, modalities, etc.)
│   ├── object.ts                     # Object name enums
│   ├── endpoint.ts                   # API endpoints
│   ├── http.ts                       # HTTP method enum
│   └── datetime.ts                   # Date/time constants
├── models/
│   ├── index.ts                      # Barrel export
│   ├── sked-models.ts                # Skedulo object interfaces
│   ├── type.ts                       # Custom type definitions
│   └── requests.ts                   # Request/response interfaces
├── services/
│   ├── data-service.ts               # Generic DataService factory
│   ├── service-factory.ts            # Service locator with caching
│   ├── object-definitions/           # Schema definitions for each object
│   │   ├── index.ts                  # Barrel export
│   │   ├── jobs-definition.ts
│   │   ├── resources-definition.ts
│   │   └── ...
│   ├── object-services/              # Specialized services
│   │   ├── index.ts                  # Barrel export
│   │   ├── jobs-service.ts
│   │   └── ...
│   └── pulse-event-queue/            # Event queue utilities
└── utils/
    ├── index.ts                      # Barrel export
    ├── configuration-variables.ts    # Typed ConfigurationVariables class
    ├── date-time-utils.ts            # Luxon-based date utilities
    └── common.ts                     # General helpers
```

## Import Patterns

All functions use the path alias `@cx/*` which maps to the symlinked `cx/` directory:

```typescript
import { Jobs, Resources, JobAllocations } from '@cx/models'
import { JobStatus, JobAllocationStatus } from '@cx/constants'
import { resolveDataService } from '@cx/services'
import { ConfigurationVariables, getDate, getStartDateTimeOfDay } from '@cx/utils'
```

## Models (`@cx/models`)

All models extend `BaseModel` from `@skedulo/pulse-solutions-framework`:

```typescript
import { BaseModel } from '@skedulo/pulse-solutions-framework'

export type Maybe<T> = T | null

export interface Jobs extends BaseModel {
  UID: string
  Name?: string
  AccountId?: Maybe<string>
  ContactId?: Maybe<string>
  Address?: Maybe<string>
  PostalCode: string
  Duration: number
  Start?: Maybe<string>
  End?: Maybe<string>
  JobStatus: string
  Type?: Maybe<string>
  RegionId: string
  Region?: Regions
  Timezone: string
  GeoLatitude?: Maybe<number>
  GeoLongitude?: Maybe<number>
  Locked?: boolean
  // Related lists
  JobAllocations: JobAllocations[]
  JobTags: JobTags[]
}

export interface Resources extends BaseModel {
  UID: string
  Name: string
  IsActive: boolean
  PrimaryRegionId: string
  PrimaryRegion: Regions
  GeoLatitude?: Maybe<number>
  GeoLongitude?: Maybe<number>
  HomeAddress?: Maybe<string>
  PostalCode: string
  // Related lists
  JobAllocations?: JobAllocations[]
  ResourceTags?: ResourceTags[]
  ResourceRegions?: ResourceRegions[]
}

export interface JobAllocations extends BaseModel {
  UID: string
  JobId?: string
  Job?: Jobs
  ResourceId: string
  Resource?: Resources
  Start?: string
  End?: string
  Duration?: number
  Status: string
  EstimatedTravelTime?: number
}

export interface Regions extends BaseModel {
  UID: string
  Name?: string
  Timezone: string
}
```

## Constants (`@cx/constants`)

Define domain enums to avoid magic strings across functions:

```typescript
export enum JobStatus {
  Cancelled = 'Cancelled',
  Complete = 'Complete',
  Dispatched = 'Dispatched',
  InProgress = 'In Progress',
  PendingAllocation = 'Pending Allocation',
  PendingDispatch = 'Pending Dispatch',
  Queued = 'Queued',
  Ready = 'Ready'
}

export enum JobAllocationStatus {
  Complete = 'Complete',
  Confirmed = 'Confirmed',
  Dispatched = 'Dispatched',
  PendingDispatch = 'Pending Dispatch',
  Deleted = 'Deleted',
  Declined = 'Declined'
}

export enum JobTagWeighting {
  Low = 1,
  Medium = 2,
  High = 3,
  Required = 4
}

export enum HTTP_METHODS {
  GET = 'GET',
  POST = 'POST',
  PUT = 'PUT',
  DELETE = 'DELETE',
  PATCH = 'PATCH'
}
```

Add project-specific enums (e.g. custom job types, modalities, activity types) to `constants/types.ts` following the same pattern.

## Service Factory Pattern (`@cx/services`)

The library uses a **service factory with caching** pattern so each object's service is created once and reused across the function invocation:

```text
resolveDataService(objectName)
        │
        ▼
┌───────────────────┐
│  Service Cache    │ ← Singleton instances (Map)
└───────┬───────────┘
        │
        ▼
┌─────────────────────────────────────┐
│ Specialized service exists?         │
│ (objectServices[camelCase+Service]) │
└──────────┬──────────────────────────┘
           │ yes                    │ no
           ▼                        ▼
  Object Service          Generic DataService
  (custom methods)        (createDataService<T>)
```

### service-factory.ts

```typescript
import { BaseModel } from '@skedulo/pulse-solutions-framework'
import { camelCase } from 'lodash'
import { createDataService } from './data-service'
import * as objectServices from './object-services'

let engineContext = new Map<string, any>()

const resolveDataService = <T extends BaseModel>(objectName: string) => {
  if (!engineContext.has(objectName)) {
    const dataServiceKey = `${camelCase(objectName)}Service` as keyof typeof objectServices
    const service = objectServices[dataServiceKey] ?? createDataService<T>(objectName)
    engineContext.set(objectName, service)
  }

  return engineContext.get(objectName)
}

export { resolveDataService }
```

### data-service.ts

```typescript
import { BaseModel, createBaseService, DataService } from '@skedulo/pulse-solutions-framework'
import * as objectDefinitions from './object-definitions'

const createDataService = <T extends BaseModel>(objectName: string): DataService<T> => {
  return createBaseService<T>({
    objectName: objectName,
    objectDefinitions: objectDefinitions
  })
}

export { createDataService }
```

### Usage Pattern

```typescript
import { resolveDataService } from '@cx/services'
import { Jobs, Resources } from '@cx/models'
import { Operator } from '@skedulo/pulse-solutions-framework'

const jobsService = resolveDataService<Jobs>('Jobs')
const resourcesService = resolveDataService<Resources>('Resources')

// Simple query
const { jobs } = await jobsService.query([
  {
    conditions: [
      ['JobStatus', Operator.IN, ['Pending Allocation', 'Queued']],
      ['Start', Operator.GREATER_OR_EQUAL, startDate]
    ],
    orderBy: 'Start ASC',
    limit: 200
  }
])

// Query with related lists
const { resources } = await resourcesService.query([
  {
    conditions: [['UID', Operator.IN, resourceIds]],
    overriddenFields: 'UID Name GeoLatitude GeoLongitude PrimaryRegion { Timezone }'
  },
  {
    relatedList: 'JobAllocations',
    conditions: [
      [['Start', 'End'], Operator.PERIOD, [startDate, endDate]],
      ['Status', Operator.NOT_IN, ['Deleted', 'Declined']]
    ],
    overriddenFields: 'UID Start End Status'
  }
])
```

## Object Definitions (`@cx/services/object-definitions`)

Each Skedulo object needs a definition file mapping fields with `MappingType`. This is what enables proper typing and GraphQL field mapping:

```typescript
// jobs-definition.ts
import { createObjectDefinition, MappingType, ObjectDefinition } from '@skedulo/pulse-solutions-framework'

export const JobsDefinition: ObjectDefinition = createObjectDefinition({
  objectName: 'Jobs',
  fieldConfigs: [
    // Standard string fields — no mappingType needed
    { fieldName: 'UID' },
    { fieldName: 'Name', readonly: true },
    { fieldName: 'AccountId' },
    { fieldName: 'JobStatus' },
    { fieldName: 'Type' },
    { fieldName: 'RegionId' },
    { fieldName: 'Timezone', readonly: true },

    // Typed fields
    { fieldName: 'Duration', mappingType: MappingType.number },
    { fieldName: 'Start', mappingType: MappingType.datetime },
    { fieldName: 'End', mappingType: MappingType.datetime },
    { fieldName: 'GeoLatitude', mappingType: MappingType.number },
    { fieldName: 'GeoLongitude', mappingType: MappingType.number },
    { fieldName: 'Locked', mappingType: MappingType.boolean },

    // Parent relationship
    { fieldName: 'Region', mappingType: MappingType.reference, referenceObject: 'Regions' },

    // Child relationships
    {
      fieldName: 'JobAllocations',
      mappingType: MappingType.relatedList,
      referenceObject: 'JobAllocations',
      parentField: 'Job'
    },
    {
      fieldName: 'JobTags',
      mappingType: MappingType.relatedList,
      referenceObject: 'JobTags',
      parentField: 'Job'
    }
  ]
})
```

### MappingType Reference

| Type                      | Usage                                          |
| ------------------------- | ---------------------------------------------- |
| `MappingType.number`      | Numeric fields (Duration, counts, coordinates) |
| `MappingType.datetime`    | ISO datetime fields (Start, End, CreatedDate)  |
| `MappingType.boolean`     | Boolean fields (Locked, IsActive, IsVirtual)   |
| `MappingType.reference`   | Parent relationship (Region, Account)          |
| `MappingType.relatedList` | Child relationship (JobAllocations, JobTags)   |

Export every definition from `src/cx/services/object-definitions/index.ts` so `createDataService` can discover them automatically.

## Specialized Object Services (`@cx/services/object-services`)

When a Skedulo object needs custom query methods beyond the generic `DataService`, create a specialized service:

```typescript
// regions-service.ts
import { DataService, Operator } from '@skedulo/pulse-solutions-framework'
import { Regions } from '../../models'
import { createDataService } from '../data-service'

type RegionsService = DataService<Regions> & {
  fetchForResource: (resourceId: string) => Promise<Regions[]>
}

const createRegionsService = (): RegionsService => {
  const base = createDataService<Regions>('Regions')

  const fetchForResource = async (resourceId: string): Promise<Regions[]> => {
    const { regions } = await base.query([
      { conditions: [['ResourceRegions.ResourceId', Operator.EQUAL, resourceId]] }
    ])
    return regions ?? []
  }

  return { ...base, fetchForResource }
}

export const regionsService = createRegionsService()
export type { RegionsService }
```

The service factory resolves specialized services by convention: `resolveDataService('Regions')` looks for `objectServices.regionsService`. Export every service from `src/cx/services/object-services/index.ts`.

## Configuration Variables (`@cx/utils`)

Centralize all configurable values in a typed static class with defaults. This prevents scattered `getVariableValue` calls and makes defaults explicit:

```typescript
import { SkedContext } from '@skedulo/function-utilities'
import { isNil } from 'lodash'

export class ConfigurationVariables {
  // Booleans
  public static ENABLE_SOME_FEATURE: boolean = false

  // Strings
  public static DEFAULT_JOB_TYPE: string = 'Standard'

  // Numbers
  public static MAX_CONCURRENT_API_CALLS: number = 10
  public static JOB_DURATION_MINUTES: number = 60

  // Arrays (stored as comma-separated strings in config)
  public static SUPPORTED_JOB_TYPES: string[] = ['Standard', 'Express']

  // API access (always required)
  public static SKEDULO_API_TOKEN: string
  public static SKEDULO_API_URL: string
}

export const initConfigVars = (skedContext: SkedContext) => {
  // Boolean
  const featureFlag = skedContext.configVars.getVariableValue('ENABLE_SOME_FEATURE')
  ConfigurationVariables.ENABLE_SOME_FEATURE = featureFlag
    ? featureFlag.toLowerCase() === 'true'
    : false

  // String with default
  ConfigurationVariables.DEFAULT_JOB_TYPE =
    skedContext.configVars.getVariableValue('DEFAULT_JOB_TYPE') || 'Standard'

  // Number
  ConfigurationVariables.JOB_DURATION_MINUTES = Number(
    skedContext.configVars.getVariableValue('JOB_DURATION_MINUTES') || '60'
  )

  // Array from comma-separated string
  const jobTypes = skedContext.configVars.getVariableValue('SUPPORTED_JOB_TYPES')
  ConfigurationVariables.SUPPORTED_JOB_TYPES = isNil(jobTypes)
    ? ['Standard', 'Express']
    : jobTypes.split(',').map((t: string) => t.trim())
}
```

Call `initConfigVars(skedContext)` once at the top of each route handler before using `ConfigurationVariables`.

## Date/Time Utilities (`@cx/utils/date-time-utils`)

Luxon-based helpers for consistent timezone handling:

```typescript
import { DateTime } from 'luxon'

// Extract ISO date from a datetime string
export const getDate = (date: string): string => {
  const dt = DateTime.fromISO(date, { setZone: true })
  return dt.isValid ? dt.toISODate() : date
}

// Start of day in a given timezone, returned as UTC
export const getStartDateTimeOfDay = (date: string, timezone = 'utc'): string => {
  const dt = DateTime.fromISO(date, { zone: timezone }).startOf('day').toUTC()
  return dt.isValid ? dt.toISO()! : date
}

// End of day in a given timezone, returned as UTC
export const getEndDateTimeOfDay = (date: string, timezone = 'utc'): string => {
  const dt = DateTime.fromISO(date, { zone: timezone })
    .set({ hour: 23, minute: 59, second: 59, millisecond: 0 })
    .toUTC()
  return dt.isValid ? dt.toISO()! : date
}

// Generate an array of ISO dates between two dates
export const generateIsoDateArray = (startDate: Date, endDate: Date, ignoreWeekend = false): string[] => {
  const isoDates: string[] = []
  let current = DateTime.fromJSDate(startDate).startOf('day')
  const endIsoDate = getDate(endDate.toISOString())

  while (current.toISODate()! <= endIsoDate!) {
    const isWeekend = current.weekday === 6 || current.weekday === 7
    if (!ignoreWeekend || !isWeekend) {
      isoDates.push(current.toISODate()!)
    }
    current = current.plus({ days: 1 })
  }
  return isoDates
}

export const isGreaterThan = (a: string, b: string): boolean => DateTime.fromISO(a) > DateTime.fromISO(b)
export const isLessThanOrEqual = (a: string, b: string): boolean => DateTime.fromISO(a) <= DateTime.fromISO(b)
export const getStartDateOfWeek = (date: string): string =>
  DateTime.fromISO(date).startOf('week').toISODate() ?? date
```

## Extending the Library

### Adding a New Object Definition

1. Create `src/cx/services/object-definitions/my-object-definition.ts`:

```typescript
import { createObjectDefinition, MappingType, ObjectDefinition } from '@skedulo/pulse-solutions-framework'

export const MyObjectDefinition: ObjectDefinition = createObjectDefinition({
  objectName: 'MyObject',
  fieldConfigs: [
    { fieldName: 'UID' },
    { fieldName: 'Name' },
    { fieldName: 'CreatedDate', mappingType: MappingType.datetime },
    { fieldName: 'IsActive', mappingType: MappingType.boolean },
    { fieldName: 'Count', mappingType: MappingType.number },
    { fieldName: 'ParentId' },
    { fieldName: 'Parent', mappingType: MappingType.reference, referenceObject: 'ParentObject' },
    {
      fieldName: 'Children',
      mappingType: MappingType.relatedList,
      referenceObject: 'ChildObject',
      parentField: 'MyObject'
    }
  ]
})
```

1. Export from `src/cx/services/object-definitions/index.ts`:

```typescript
export * from './my-object-definition'
```

### Adding a New Specialized Service

1. Create `src/cx/services/object-services/my-object-service.ts`:

```typescript
import { DataService, Operator } from '@skedulo/pulse-solutions-framework'
import { MyObject } from '../../models'
import { createDataService } from '../data-service'

type MyObjectService = DataService<MyObject> & {
  findActiveByParent: (parentId: string) => Promise<MyObject[]>
}

const createMyObjectService = (): MyObjectService => {
  const base = createDataService<MyObject>('MyObject')

  const findActiveByParent = async (parentId: string): Promise<MyObject[]> => {
    const { myObjects } = await base.query([
      {
        conditions: [
          ['ParentId', Operator.EQUAL, parentId],
          ['IsActive', Operator.EQUAL, true]
        ],
        orderBy: 'Name ASC'
      }
    ])
    return myObjects
  }

  return { ...base, findActiveByParent }
}

export const myObjectService = createMyObjectService()
export type { MyObjectService }
```

1. Export from `src/cx/services/object-services/index.ts`:

```typescript
export * from './my-object-service'
```

### Adding a New Model

Add the interface to `src/cx/models/sked-models.ts`:

```typescript
export interface MyObject extends BaseModel {
  UID: string
  Name: string
  CreatedDate?: Maybe<string>
  IsActive: boolean
  Count: number
  ParentId?: Maybe<string>
  Parent?: ParentObject
  Children?: ChildObject[]
}
```

## Testing

### Jest Configuration

```typescript
// src/cx/jest.config.ts
import type { Config } from 'jest'

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>'],
  testMatch: ['**/__tests__/**/*.test.ts'],
  moduleNameMapper: {
    '^@cx/(.*)$': '<rootDir>/src/cx/$1',
    '^@skedulo/pulse-solutions-framework$': '<rootDir>/__mocks__/pulse-solutions-framework.ts'
  },
  collectCoverageFrom: ['**/*.ts', '!**/*.d.ts', '!**/__tests__/**', '!**/node_modules/**'],
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 80, statements: 80 }
  }
}

export default config
```

### Mocking `resolveDataService`

```typescript
import { resolveDataService } from '../service-factory'
import { myCustomFunction } from '../object-services/my-service'

jest.mock('../service-factory', () => ({ resolveDataService: jest.fn() }))

describe('myCustomFunction', () => {
  const mockService = { query: jest.fn(), save: jest.fn() }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(resolveDataService as jest.Mock).mockReturnValue(mockService)
  })

  it('queries with correct conditions', async () => {
    mockService.query.mockResolvedValue({ jobs: [{ UID: '1', JobStatus: 'Queued' }] })

    const result = await myCustomFunction('Queued')

    expect(resolveDataService).toHaveBeenCalledWith('Jobs')
    expect(result).toHaveLength(1)
  })
})
```

### Mocking `pulse-solutions-framework`

```typescript
// __mocks__/pulse-solutions-framework.ts
export const initExecutionContext = jest.fn()
export const getExecutionContext = jest.fn().mockReturnValue({
  baseClient: { performRequest: jest.fn() }
})
export const createBaseService = jest.fn().mockReturnValue({
  query: jest.fn().mockResolvedValue({}),
  save: jest.fn().mockResolvedValue({ success: true })
})
export const createObjectDefinition = jest.fn().mockImplementation(config => config)

export enum Operator {
  EQUAL = 'EQUAL',
  NOT_EQUAL = 'NOT_EQUAL',
  IN = 'IN',
  NOT_IN = 'NOT_IN',
  GREATER_OR_EQUAL = 'GREATER_OR_EQUAL',
  LESS_OR_EQUAL = 'LESS_OR_EQUAL',
  GREATER_THAN = 'GREATER_THAN',
  LESS_THAN = 'LESS_THAN',
  PERIOD = 'PERIOD',
  LIKE = 'LIKE'
}

export enum MappingType {
  number = 'number',
  datetime = 'datetime',
  boolean = 'boolean',
  reference = 'reference',
  relatedList = 'relatedList'
}

export interface BaseModel {
  UID: string
  Name?: string
}
```

### Test Fixtures

```typescript
// __tests__/fixtures/jobs.ts
import { Jobs } from '../../models'

export const createMockJob = (overrides: Partial<Jobs> = {}): Jobs => ({
  UID: 'job-' + Math.random().toString(36).substr(2, 9),
  Name: 'Test Job',
  JobStatus: 'Pending Allocation',
  Duration: 60,
  RegionId: 'region-123',
  Timezone: 'UTC',
  PostalCode: '10001',
  JobAllocations: [],
  JobTags: [],
  ...overrides
})

export const createMockResource = (overrides = {}) => ({
  UID: 'resource-' + Math.random().toString(36).substr(2, 9),
  Name: 'Test Resource',
  IsActive: true,
  PrimaryRegionId: 'region-123',
  PrimaryRegion: { UID: 'region-123', Timezone: 'UTC' },
  PostalCode: '10001',
  ...overrides
})
```

### Running Tests

```bash
# Run all @cx tests
cd src/cx && yarn test

# Run with coverage
cd src/cx && yarn test --coverage

# Watch mode
cd src/cx && yarn test --watch
```

## Best Practices

**Do:**

- Use `resolveDataService()` for all data access — it handles caching
- Define an object definition for every Skedulo object you query
- Use typed models extending `BaseModel`
- Put all configurable values in `ConfigurationVariables`
- Use date utilities from `@cx/utils` — never raw `Date` objects
- Create specialized services for complex or reused query logic
- Export everything through barrel `index.ts` files

**Don't:**

- Call `createBaseService()` directly — use `createDataService()` instead
- Hardcode configuration values or status strings
- Skip object definitions — they are required for proper field mapping
- Duplicate query logic across functions — move it to a specialized service
