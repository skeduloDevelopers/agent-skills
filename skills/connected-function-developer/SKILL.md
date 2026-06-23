---
name: connected-function-developer
description: This skill enables Claude to build, modify, and deploy Skedulo custom functions. Custom functions are server-side APIs that run on Skedulo's platform without requiring users to manage their own infrastructure.
---

# Skedulo Custom Functions Skill

## What Are Skedulo Custom Functions?

Custom functions are Skedulo's serverless API platform. They provide stateless, authenticated APIs for custom business logic and third-party integrations.

**Key Benefits:**
- No server infrastructure to manage
- Automatic authentication via Bearer tokens
- Native integration with Skedulo platform
- Can be triggered by webhooks, actions, or extensions

## Core Concepts

### Function Structure

Every function has this file structure:
```
my-function/
├── sked.proj.json       # Function configuration and settings
├── state.json           # Metadata for CLI operations
├── package.json         # Node.js dependencies
├── tsconfig.json        # TypeScript configuration
├── src/
│   ├── handler.ts       # Main entry point
│   ├── routes.ts        # Route definitions
│   └── types.ts         # Type definitions
└── .env                 # Local config variables (not deployed)
```

### sked.proj.json

This file defines the function configuration:

```json
{
  "type": "function",
  "version": "2",
  "name": "my-function-name",
  "description": "Clear description of what this function does",
  "runtime": "nodejs24.x",
  "settings": {
    "configVars": [
      {
        "name": "VARIABLE_NAME",
        "configType": "plain-text",
        "description": "What this variable is for",
        "default": "default-value"
      }
    ]
  }
}
```

**Key Properties:**
- `type`: Always "function"
- `version`: Always "2"
- `name`: Lowercase with hyphens, describes purpose
- `description`: Clear explanation for administrators
- `runtime`: Use "nodejs18.x"
- `settings.configVars`: Array of configuration variables

### Configuration Variables

Configuration variables let administrators customize function behavior without code changes.

**Types:**
- `plain-text`: Regular string values
- `secret`: Encrypted values (API keys, passwords)

**Best Practices:**
- Always provide default values when reasonable
- Use descriptive names in SCREAMING_SNAKE_CASE
- Write clear descriptions for administrators
- Access via: `skedContext?.configVars?.getVariableValue("VAR_NAME")`

**Example:**
```typescript
const apiKey = skedContext?.configVars?.getVariableValue("STRIPE_API_KEY");
if (!apiKey) {
  return {
    status: 400,
    body: { error: "STRIPE_API_KEY not configured" }
  };
}
```

### Routes

Routes define the API endpoints. Use the `routes.ts` file:

```typescript
import { FunctionRoute } from "@skedulo/sdk-utilities";
import * as pathToRegExp from "path-to-regexp";

export function getCompiledRoutes() {
  return getRoutes().map((route) => {
    const regex = pathToRegExp(route.path);
    return {
      regex,
      method: route.method,
      handler: route.handler,
    };
  });
}

function getRoutes(): FunctionRoute[] {
  return [
    {
      method: "get",
      path: "/health",
      handler: async (__, headers, method, path, skedContext) => {
        return {
          status: 200,
          body: { status: "healthy" }
        };
      },
    },
    {
      method: "post",
      path: "/process",
      handler: async (body, headers, method, path, skedContext) => {
        // body is already parsed JSON
        const result = await processData(body);
        return {
          status: 200,
          body: { result }
        };
      },
    }
  ];
}
```

**Handler Parameters:**
- `body`: Parsed request body (for POST/PUT/PATCH)
- `headers`: Request headers object
- `method`: HTTP method (GET, POST, etc.)
- `path`: Request path
- `skedContext`: Skedulo context with config vars and utilities

**Response Format:**
```typescript
{
  status: number,           // HTTP status code
  body: object | string,    // Response data
  headers?: object          // Optional response headers
}
```

### Handler.ts

The main entry point processes requests:

```typescript
import { Request, Response } from "express";
import { getCompiledRoutes } from "./routes";
import { createSkedContext } from "@skedulo/function-utilities";

export const handler = async (req: Request, res: Response) => {
  try {
    const skedContext = createSkedContext(req.headers);
    const routes = getCompiledRoutes();
    
    // Find matching route
    const matchedRoute = routes.find((route) => {
      return route.method === req.method.toLowerCase() && 
             route.regex.test(req.path);
    });

    if (!matchedRoute) {
      res.status(404).json({ error: "Route not found" });
      return;
    }

    // Execute handler
    const result = await matchedRoute.handler(
      req.body,
      req.headers,
      req.method,
      req.path,
      skedContext
    );

    res.status(result.status).json(result.body);
  } catch (error) {
    console.error("Function error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
};
```

## Development Workflow

### 1. Generate Function

```bash
sked function generate --name my-function --outputdir .
cd my-function
```

### 2. Install Dependencies

```bash
yarn bootstrap
```

#### Required dependency resolution (webpack bundling fix)

Every function that imports `@skedulo/pulse-solution-services` (i.e. anything using the Skedulo API or
its logger) transitively pulls `winston` → `@dabh/diagnostics`. From `@dabh/diagnostics@2.0.5` the
package switched its color dependency from the original `colorspace` (which used `color@3`) to the
`@so-ric/colorspace` fork (which uses `color@5`). Both the fork and `color@5` ship ES2021 numeric
separators (e.g. `0.003_130_8`) that the scaffold's **webpack 4** bundler cannot parse, because
node_modules is not transpiled. The build then fails with
`Module parse failed: Identifier directly after number`.

> Note: a `--mode=production` bundle dead-code-eliminates the diagnostics *development* branch and so
> dodges this, but the default/`development` bundle that `sked function dev` and deploy dry-runs use
> hits it. A green `yarn compile` (production) does not mean the function deploys.

Pin `@dabh/diagnostics` back to the last version that uses the original, webpack-4-safe color stack,
in `package.json` `resolutions`. Use the **exact** version `2.0.3` — `^2.0.3` would re-allow 2.0.8:

```json
{
  "resolutions": {
    "@dabh/diagnostics": "2.0.3"
  }
}
```

This drops `@so-ric/colorspace`/`color@5` from the tree (reverting to `colorspace@1.1.4` + `color@3`)
and does not change winston's logging behaviour. yarn warns that the resolution is incompatible with
winston's requested `^2.0.8` range — that warning is expected. Because this changes `package.json`,
refresh the lockfile with a non-frozen `yarn install` so the resolution is recorded; `yarn bootstrap`'s
`--frozen-lockfile` fails until the lockfile reflects the pin.

### 3. Develop Locally

```bash
# Compile TypeScript
yarn compile

# Start dev server
sked function dev . -p 3000

# Test in another terminal
curl --location 'http://127.0.0.1:3000/health' \
  --header 'Authorization: Bearer <token>'
```

### 4. Deploy to Tenant

```bash
# Single function deploy
sked artifacts function upsert -f state.json

# Or as part of package
sked package deploy -p .
```

### 5. Test Deployed Function

```bash
# List functions to get baseUrl
sked artifacts function list

# Test deployed function
curl --location '<baseUrl>/health' \
  --header 'Authorization: Bearer <token>'
```

## Common Patterns

### REST API Endpoint

```typescript
{
  method: "post",
  path: "/api/customers",
  handler: async (body, headers, method, path, skedContext) => {
    // Validate input
    if (!body.email) {
      return {
        status: 400,
        body: { error: "Email required" }
      };
    }

    // Process request
    const customer = await createCustomer(body);

    return {
      status: 201,
      body: { customer }
    };
  },
}
```

### Webhook Receiver

```typescript
{
  method: "post",
  path: "/webhooks/stripe",
  handler: async (body, headers, method, path, skedContext) => {
    const signature = headers["stripe-signature"];
    const secret = skedContext?.configVars?.getVariableValue("STRIPE_WEBHOOK_SECRET");

    // Verify webhook signature
    if (!verifyStripeSignature(body, signature, secret)) {
      return {
        status: 401,
        body: { error: "Invalid signature" }
      };
    }

    // Process webhook
    await processStripeEvent(body);

    return {
      status: 200,
      body: { received: true }
    };
  },
}
```

### Integration with Skedulo GraphQL

**IMPORTANT**: When accessing Skedulo's GraphQL API, ALWAYS use the `@skedulo/pulse-solution-services` library and the `connected-function:skedulo-api-developer` skill for guidance.

```typescript
import { ExecutionContext } from "@skedulo/pulse-solution-services";

{
  method: "get",
  path: "/jobs/:jobId",
  handler: async (__, headers, method, path, skedContext) => {
    const jobId = path.split("/").pop();

    try {
      // Initialize ExecutionContext
      const context = ExecutionContext.fromContext(skedContext, {
        requestSource: "custom-function",
        userAgent: "job-fetcher"
      });

      // Use QueryBuilder for type-safe queries
      const result = await context
        .newQueryBuilder({
          objectName: "Jobs",
          operationName: "getJob"
        })
        .withFields(["UID", "Name", "JobStatus"])
        .withFilter(`UID = '${jobId}'`)
        .execute();

      if (result.records.length === 0) {
        return {
          status: 404,
          body: { error: "Job not found" }
        };
      }

      return {
        status: 200,
        body: result.records[0]
      };
    } catch (error) {
      console.error("Failed to fetch job:", error);
      return {
        status: 500,
        body: { error: "Failed to fetch job data" }
      };
    }
  },
}
```

**Key Benefits of using `@skedulo/pulse-solution-services`:**
- Type-safe query building
- Automatic pagination support
- Built-in error handling
- Performance monitoring
- Consistent patterns across the platform

**When to use the `connected-function:skedulo-api-developer` skill:**
- Any time you need to query or mutate Skedulo data
- When implementing batch operations
- For complex GraphQL queries with relationships
- When performance optimization is needed
- For proper error handling patterns

### Error Handling

```typescript
{
  method: "post",
  path: "/process",
  handler: async (body, headers, method, path, skedContext) => {
    try {
      const result = await riskyOperation(body);
      return {
        status: 200,
        body: { result }
      };
    } catch (error) {
      console.error("Process error:", error);
      
      if (error.code === "VALIDATION_ERROR") {
        return {
          status: 400,
          body: { error: error.message }
        };
      }
      
      return {
        status: 500,
        body: { error: "Processing failed" }
      };
    }
  },
}
```

## Code Generation Guidelines

### When Creating New Functions

1. **Use descriptive names:** `customer-validator`, `stripe-integration`, `schedule-optimizer`
2. **Write clear descriptions:** Help administrators understand the purpose
3. **Include health check route:** Always add a GET /health endpoint
4. **Set up config vars early:** Define any API keys or settings upfront
5. **Add error handling:** Every route should handle errors gracefully
6. **Use TypeScript types:** Define interfaces for request/response bodies
7. **Use `@skedulo/pulse-solution-services`:** For all Skedulo API interactions
8. **Leverage skills:** Use `connected-function:skedulo-api-developer` skill when accessing Skedulo data

### When Modifying Functions

1. **Preserve existing routes:** Don't remove routes without explicit instruction
2. **Match code style:** Follow the patterns already in the file
3. **Update dependencies:** Add new npm packages to package.json if needed
4. **Test locally first:** Always remind user to test with `sked function dev`
5. **Document changes:** Update function description if behavior changes

### Code Style

```typescript
// Good: Clear, typed, error-handled
{
  method: "post",
  path: "/validate-email",
  handler: async (body, headers, method, path, skedContext) => {
    const { email } = body;
    
    if (!email || typeof email !== "string") {
      return {
        status: 400,
        body: { error: "Valid email required" }
      };
    }

    const isValid = validateEmailFormat(email);
    
    return {
      status: 200,
      body: { email, isValid }
    };
  },
}

// Bad: No validation, unclear purpose
{
  method: "post",
  path: "/check",
  handler: async (body) => {
    const result = doSomething(body.data);
    return { status: 200, body: result };
  },
}
```

## Testing Strategy

### Local Testing with .env

Create `.env` file for local config vars:
```
STRIPE_API_KEY=sk_test_xxxxx
WEBHOOK_SECRET=whsec_xxxxx
API_ENDPOINT=https://api.example.com
```

### Unit Testing
- Ensure you have at least 80% unit test coverage on call produced

Add to package.json:
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0"
  }
}
```

Create test file:
```typescript
import { handler } from "./handler";

describe("Function handler", () => {
  it("should return health status", async () => {
    const req = {
      method: "GET",
      path: "/health",
      headers: {},
      body: {}
    };
    
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };

    await handler(req as any, res as any);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ status: "healthy" });
  });
});
```

## Security Best Practices

1. **Always validate input:** Check types, required fields, formats
2. **Use config vars for secrets:** Never hardcode API keys
3. **Verify webhook signatures:** For external integrations
4. **Sanitize user input:** Prevent injection attacks
5. **Use Bearer token auth:** Already handled by platform
6. **Log errors carefully:** Don't log sensitive data

## Deployment Checklist

Before deploying:
- [ ] Function compiles without errors
- [ ] All routes tested locally
- [ ] Config vars defined with defaults
- [ ] Error handling in place
- [ ] Description updated in sked.proj.json
- [ ] Dependencies listed in package.json
- [ ] No secrets in code (use config vars)

## Common Issues

### "Module parse failed: Identifier directly after number" (webpack)
Cause: `@dabh/diagnostics@2.0.5+` (pulled transitively by `@skedulo/pulse-solution-services` →
`winston`) switched to the `@so-ric/colorspace` fork + `color@5`, which ship ES2021 numeric separators
that webpack 4 cannot parse (node_modules is not transpiled). Default/development bundles fail;
production bundles mask it via dead-code elimination, so don't trust a green `yarn compile`.
Solution: pin `"@dabh/diagnostics": "2.0.3"` (exact, not `^`) in `package.json` `resolutions`, then run
`yarn install` (non-frozen) to refresh the lockfile and rebuild. See "Required dependency resolution"
under Development Workflow.

### "Cannot find module"
Solution: Run `yarn bootstrap` to install dependencies

### "Config variable not found"
Solution: Add to .env for local testing, or create in tenant settings

### "Route not found"
Solution: Check path format and HTTP method match

### "Unauthorized"
Solution: Ensure valid Bearer token in Authorization header

### Function times out
Solution: Check for infinite loops, optimize database queries, add timeouts

## Advanced Features

### Path Parameters

```typescript
{
  method: "get",
  path: "/users/:userId/jobs/:jobId",
  handler: async (__, headers, method, path, skedContext) => {
    const pathParts = path.split("/");
    const userId = pathParts[2];
    const jobId = pathParts[4];
    
    // Use parameters
  },
}
```

### Query Parameters

```typescript
{
  method: "get",
  path: "/search",
  handler: async (__, headers, method, path, skedContext) => {
    const url = new URL(`http://localhost${path}`);
    const query = url.searchParams.get("q");
    const limit = parseInt(url.searchParams.get("limit") || "10");
    
    // Use query params
  },
}
```

### Custom Headers

```typescript
{
  method: "get",
  path: "/data",
  handler: async (__, headers, method, path, skedContext) => {
    return {
      status: 200,
      body: { data: "value" },
      headers: {
        "Cache-Control": "max-age=3600",
        "X-Custom-Header": "value"
      }
    };
  },
}
```

## Integration Patterns

### Triggered Actions
Functions can be called by Skedulo triggered actions when records change.

### Webhooks
External systems can POST to function endpoints.

### Web Extensions
Custom UI components can call functions via fetch.

### Mobile Extensions
Mobile apps can invoke functions for custom logic.

## Triggered Actions, Event Queueing, and the @cx Library

These topics live in their own focused skills — load the matching one on demand rather than carrying it here:

- **Triggered actions** (manifests, `createTriggeredActionHandler`, `object_modified` triggers, `POST /triggered-action/*`, deploy CLI) → load the **`connected-function-triggered-actions`** skill.
- **Event queueing** (large/bursty triggered-action payloads, async queue + worker, bulk enqueue) → load the **`connected-function-event-queue`** skill.
- **`@cx` shared library** (shared models, service factory, object definitions, config across functions) → load the **`connected-function-cx-library`** skill.

## Resources

- Skedulo CLI: Run `sked function generate --help`
- Function utilities: `@skedulo/function-utilities` npm package
- GraphQL client: Access via `skedContext.graphQL`
- Platform docs: Check Skedulo documentation portal
- Triggered actions: load the `connected-function-triggered-actions` skill
- Event queueing for large batches: load the `connected-function-event-queue` skill
- `@cx` shared library: load the `connected-function-cx-library` skill

## Working with Skedulo APIs

### Always Use the Proper Library

When your function needs to interact with Skedulo data:

**DO:**
- Use `@skedulo/pulse-solution-services` library
- Initialize ExecutionContext from skedContext
- Use QueryBuilder for GraphQL queries
- Follow patterns from `connected-function:skedulo-api-developer` skill
- Handle errors with try-catch blocks
- Log errors for debugging

**DON'T:**
- Use raw GraphQL queries with string templates
- Skip error handling
- Ignore execution limits
- Hardcode query filters

### Example: Adding Skedulo API Access to a Function

```bash
# 1. Add the dependency
cd src/functions/my-function
yarn add @skedulo/pulse-solution-services

# 2. Import in your routes.ts
import { ExecutionContext } from "@skedulo/pulse-solution-services";

# 3. Initialize in your handler
const context = ExecutionContext.fromContext(skedContext, {
  requestSource: "my-function",
  userAgent: "handler-name"
});

# 4. Build and execute queries
const result = await context
  .newQueryBuilder({ objectName: "Jobs", operationName: "fetchJobs" })
  .withFields(["UID", "Name"])
  .execute();
```

## Summary

When building or modifying Skedulo custom functions:
1. Use clear naming and descriptions
2. Add configuration variables for flexibility
3. Implement proper error handling
4. Test locally before deploying
5. Follow security best practices
6. Keep routes focused and simple
7. Document your code
8. **Use `@skedulo/pulse-solution-services` for all Skedulo API access**
9. **Leverage the `skedulo-api-developer` skill for API patterns**

This skill enables rapid development of production-ready Skedulo functions that integrate seamlessly with the platform.
