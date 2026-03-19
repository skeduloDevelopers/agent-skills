# skedulo-api-developer

Expert patterns for building high-performance solutions with Skedulo Pulse APIs.

## Use this skill when

- Working with `@skedulo/pulse-solution-services` in any Pulse Platform function
- Writing GraphQL queries or mutations against the Skedulo API
- Writing EQL (Extended Query Language) filter expressions
- Implementing batch operations (read or write) on Pulse data
- Validating resources or checking availability
- Optimizing API performance in Connected Functions or Optimization Extensions
- Debugging API errors, rate limits, or unexpected query results

## What to expect

Once activated, this skill enforces correct patterns for using `@skedulo/pulse-solution-services` — including proper client initialization, GraphQL query structure, EQL syntax, batch sizing, and error handling. It prevents common mistakes like N+1 queries, incorrect EQL operators, and missing required fields.

## Example

    // Fetch all jobs for a region using a batch read
    const jobs = await sdk.sked.query.readObjects('Jobs', {
      filter: `RegionId == '${regionId}'`,
      fields: ['UID', 'Name', 'Status', 'Start', 'End']
    })
