# Skedulo Connected Functions

Build, modify, and deploy Skedulo custom functions — stateless, authenticated serverless APIs for custom business logic and third-party integrations on the Pulse Platform.

## Use this skill when

- Creating a new connected/custom function
- Adding routes or business logic to an existing function
- Wiring a function as the target of a webhook, triggered action, or optimization extension
- Configuring `sked.proj.json` (runtime, config vars) or deploying a function
- Debugging function auth, routing, or deployment errors

## Key rules

- Follow the standard layout: `sked.proj.json`, `state.json`, `src/handler.ts`, `src/routes.ts`
- `sked.proj.json` declares `type: "function"`, `version`, `runtime`, and `settings.configVars`
- Functions are stateless; authentication is automatic via Bearer tokens
- Keep secrets in config vars / `.env` (not deployed) — never hard-code them
- Deploy with the Skedulo CLI (see the `skedulo-cli` skill)

## Example

```typescript
// src/routes.ts — register an HTTP route
router.post('/greet', async ({ body }) => ({
  status: 200,
  body: { message: `Hello ${body.name}` }
}))
```
