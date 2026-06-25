# Skedulo API Developer

Expert patterns for building high-performance solutions with Skedulo Pulse APIs (`@skedulo/pulse-solution-services`) — GraphQL, EQL, batch operations, and performance optimization.

## Use this skill when

- Writing GraphQL queries/mutations or EQL filters against Pulse data
- Working with `@skedulo/pulse-solution-services` or `@skedulo/pulse-solutions-framework`
- Running batch operations, resource validation, or recurring-date generation
- Optimizing API performance inside Pulse platform functions
- Initializing an execution context in a function

## Key rules

- Initialize `ExecutionContext.fromContext(skedContext, …)` first; set meaningful `requestSource` / `userAgent`
- Respect execution limits (50 total calls, 5 concurrent, 12s) — override deliberately when you need more
- Use correct EQL syntax for filters and batch operations to stay within limits
- Prefer the framework services over raw HTTP so auth and observability are handled for you

## Example

```javascript
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "my-project",
  userAgent: "my-function"
})
```
