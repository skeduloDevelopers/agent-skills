# optimization-extension-developer

Build, modify, and deploy Skedulo Optimization Extensions on the Pulse Platform.

## Use this skill when

- Creating a new Optimization Extension for the Pulse optimization engine
- Implementing pre- or post-optimization data transformation hooks
- Filtering jobs or resources before an optimization run
- Applying custom constraints to an optimization problem
- Debugging unexpected optimization results or extension errors
- Deploying or updating an Optimization Extension to a tenant
- Understanding the data contract between the optimization engine and extensions

## What to expect

Once activated, this skill guides correct extension structure, hook signatures, data transformation patterns, and deployment workflows. It covers the optimization engine's data model, how to filter and constrain jobs and resources, and safe patterns for transforming optimization input and output without breaking the core engine.

## Example

    // Pre-optimization hook — filter out jobs outside working hours
    export const preOptimize = async (data: OptimizationInput) => {
      data.jobs = data.jobs.filter(job => isWithinWorkingHours(job))
      return data
    }
