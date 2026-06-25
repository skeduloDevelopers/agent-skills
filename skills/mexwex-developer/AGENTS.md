# Skedulo MEXWEX (WebView Forms)

Build, modify, and validate MEXWEX forms — WebView-based mobile forms that talk to the native Skedulo Plus shell via the `@skedulo/mexwex-bridge` SDK.

## Use this skill when

- `ui_def.json` is `{ "type": "mexwex" }`, or the project has a `mexwex/` folder alongside `mex_definition/`
- Building an API-driven, inherently online form (payment, integration, bespoke UI)
- Integrating a third-party SDK (Stripe, mapping, charts) into a Skedulo mobile form
- Calling live APIs (Skedulo GraphQL, a custom function backend) from a WebView UI

## Key rules

- A MEXWEX form is a web app in `mexwex/` (React + Vite + Breeze UI, bundled to a single HTML file) plus a minimal `mex_definition/`
- `ui_def.json` is ALWAYS just `{ "type": "mexwex" }`; `instanceFetch.json` / `staticFetch.json` are usually empty `{}`
- MEXWEX forms are inherently online — for offline/CRUD on Skedulo data, use `mex-developer`
- Fetch data and bearer tokens through the `@skedulo/mexwex-bridge` SDK, not by hard-coding credentials

## Example

```json
// mex_definition/ui_def.json — always exactly this for MEXWEX
{ "type": "mexwex" }
```
