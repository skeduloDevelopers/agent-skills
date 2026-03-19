# connected-function-developer

Build, modify, and deploy Skedulo custom functions on the Pulse Platform.

## Use this skill when

- Creating a new Skedulo custom function (Connected Function)
- Modifying an existing custom function's business logic
- Implementing authentication or authorization in a function handler
- Building third-party integrations via custom function endpoints
- Deploying or redeploying a function to a Pulse tenant
- Debugging function errors, cold starts, or request handling issues
- Structuring function projects (routing, middleware, handlers)

## What to expect

Once activated, this skill guides correct project structure, handler patterns, request/response handling, and deployment workflows for Skedulo custom functions. It covers authentication context, error handling conventions, and how to interact with the Pulse API from within a function.

## Example

    // Basic custom function handler
    export const handler = async (req: Request, context: FunctionContext) => {
      const { uid } = context.auth
      // ... business logic
      return new Response(JSON.stringify({ result }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }
