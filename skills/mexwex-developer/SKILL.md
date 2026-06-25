---
name: mexwex-developer
description: This skill enables Claude to build, modify, and validate MEXWEX forms for Skedulo Plus — WebView-based mobile forms that talk to the native shell via the @skedulo/mexwex-bridge SDK. Activate when ui_def.json is `{ "type": "mexwex" }`, when the project has a `mexwex/` folder alongside `mex_definition/`, or when the user asks to build a MEXWEX form, payment form, integration form, or any form that calls live APIs from a WebView UI.
---

# Skedulo MEXWEX Skill

## What is MEXWEX?

MEXWEX is the WebView-based mode of Skedulo Mobile Extensions. Instead of declaring the form UI in `ui_def.json` page-by-page (Standard MEX), the entire form UI is a small **web app** that ships as a single bundled `index.html`. The Skedulo mobile app loads that bundle into a `WebView` and exposes a host bridge — the **`@skedulo/mexwex-bridge` SDK** — for the form to fetch data, save changes, capture attachments, and exit.

A MEXWEX form is therefore two things deployed together:

1. A **web app** in `mexwex/` (React + Vite + Breeze UI, bundled into a single HTML file).
2. A minimal **MEX definition** in `mex_definition/` plus `upload_config.json` so the Skedulo platform knows where the form attaches and how to load it.

MEXWEX forms are **inherently online**: they call live APIs at runtime (Skedulo's GraphQL endpoint, your custom-function backend, or any other service) using bearer tokens obtained from the bridge.

## When to use MEXWEX vs Standard MEX

See [When to use MEXWEX](./references/when-to-use-mexwex.md) for the decision tree. Short version:

- **Use MEXWEX when** the form is API-driven, has bespoke UI / interaction patterns, integrates a third-party SDK (Stripe, mapping, charts), or is fundamentally online.
- **Use Standard MEX when** the form is a CRUD form on Skedulo data with offline support, or is composed entirely of standard editor / display components.

If the user wants offline capability with cached data, **Standard MEX** is the right choice — see the `mex-developer` skill instead.

## Project structure

```text
<form-root>/
├── upload_config.json                    # name, defId, engineVersion
├── mex_definition/
│   ├── ui_def.json                       # ALWAYS just { "type": "mexwex" }
│   ├── metadata.json                     # contextObject, etc.
│   ├── instanceFetch.json                # usually empty {} (data fetched on demand by the web app)
│   ├── staticFetch.json                  # usually empty {}
│   └── static_resources/
│       └── locales/en.json
├── mexwex/                               # the web app — the bundled UI
│   ├── package.json                      # depends on @skedulo/mexwex-bridge, @skedulo/breeze-ui-react, vite, vite-plugin-singlefile
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       ├── main.jsx
│       ├── App.jsx
│       └── navigation/                   # in-bundle stack navigation
└── custom_functions/                     # OPTIONAL: backend handlers the web app calls
    └── ...
```

`mex_definition/ui_def.json` is the entire UI declaration on the MEX side — **always** the literal single-property object:

```json
{ "type": "mexwex" }
```

All UI work happens inside `mexwex/`.

## Hard rules

These prevent silent failures and runtime errors. Treat as non-negotiable.

1. **Scaffold every new MEXWEX project with `sked mex template sync-mexwex`.** This is the only sanctioned way to create the `mexwex/` web app, `vite.config.js`, `package.json`, and the minimal `mex_definition/` files. Do **not** hand-write these files from scratch and do **not** copy them out of another repo — the Copier template ships the canonical structure, exact dependency versions, and the single-file Vite config that the native WebView requires. Run the same command again on an existing project to merge in template updates. See [Project Setup](./references/project-setup.md). Hand-rolled scaffolds drift from the host runtime and fail silently in production WebViews.
2. **`ui_def.json` is exactly `{ "type": "mexwex" }`.** Do not add other properties. Do not nest `mexwex` inside other config. Standard MEX page definitions are ignored when `type === "mexwex"`.
3. **The bundle must build to a single self-contained `index.html`.** Use `vite-plugin-singlefile`. The native WebView loads from a file URI — separate JS / CSS files will not resolve. See [Project Setup](./references/project-setup.md).
4. **Always import the SDK as `@skedulo/mexwex-bridge`.** Do not redeclare bridge methods or call `window.ReactNativeWebView.postMessage` directly — the SDK already wraps that with timeout + request-id correlation.
5. **User-interactive bridge methods have NO timeout.** `captureSignature` and `captureAttachments` wait forever for the user. Do not wrap them in your own timeouts.
6. **Authenticate every API call with the token from `getAuthenticationInfo()`.** Tokens can rotate during a session — fetch on call, do not assume a long-lived cache. See [Authentication & API](./references/authentication-and-api.md).
7. **Call `saveInstanceData()` to persist form data.** Local React state is lost when the form closes. The bridge writes to native storage which syncs to the server.
8. **Send `sendExtensionMandatoryStatus(true | false)` whenever the user can save.** The host UI gates the save button on this signal — forget it and the user cannot save.
9. **Call `exit()` to leave the form.** Do not try to `window.history.back()` past the initial route. The host listens for `onNativeBackPress` and forwards Android hardware-back into the bundle; handle it via the navigation provider.
10. **NEVER invent bridge methods or parameters.** Only the methods documented in [Bridge API](./references/bridge-api.md) exist. If the SDK does not expose it, it cannot be done from the web side.
11. **NEVER invent GraphQL fields, input types, or mutation names.** Only send fields that the requirements explicitly identify as writable, plus obvious bookkeeping (`UID` for update, foreign keys to establish the relationship). Do **not** include "helpful" extras (e.g. denormalised display names like `Name`, audit fields like `CreatedDate`, computed totals). Tenant schemas commonly mark such fields as read-only, computed, or restricted — sending them is rejected with a schema error, or worse, accepted and silently overwrites server-managed state with stale client values. Same rule for SELECT sets: don't fetch fields you won't display. See [Authentication & API → GraphQL writes](./references/authentication-and-api.md).
12. **Never reference internal Skedulo source paths in code or comments.** Use the public package names (`@skedulo/mexwex-bridge`, `@skedulo/breeze-ui-react`, `@skedulo/breeze-ui`) only.
13. **Use Breeze UI React components for anything chrome-like** (buttons, inputs, cards, alerts). Do not hand-roll styled equivalents — Breeze gives you Skedulo's mobile-first design tokens for free.

## Form lifecycle (one paragraph)

When the user opens a MEXWEX form, the WebView loads `index.html`, the React app boots, and the bridge initialises. The app calls `getInstanceData()` (and `getStaticData()` if needed) to load form state, calls `getMetadata()` once for context (job, user, timezone), and renders. As the user edits, the app keeps state in React (or Zustand) and periodically calls `saveInstanceData(data)` and `sendExtensionMandatoryStatus(complete)`. When the user is done they (or the app) call `exit()`. Full sequence: [Form Lifecycle](./references/form-lifecycle.md).

## Reference index

Read these files on demand based on what you need.

| When you need to… | Read this file |
|---|---|
| Choose between MEXWEX and Standard MEX | [When to use MEXWEX](./references/when-to-use-mexwex.md) |
| Scaffold a new MEXWEX project, configure deps and Vite, run the dev loop | [Project Setup](./references/project-setup.md) |
| Look up any bridge method (params, return type, errors, timeouts) | [Bridge API Reference](./references/bridge-api.md) |
| Wire up data load, save, mandatory-status, and exit | [Form Lifecycle](./references/form-lifecycle.md) |
| Capture and persist photos, files, or signatures | [Attachments & Signatures](./references/attachments-and-signatures.md) |
| Call your custom-function backend or other Skedulo APIs | [Authentication & API](./references/authentication-and-api.md) |
| Build in-bundle navigation, layout pages, use Breeze UI | [Navigation & UI](./references/navigation-and-ui.md) |
| Validate a MEXWEX form before deploy | [Review Checklist](./references/review-checklist.md) |

## Calling a custom-function backend

A common MEXWEX pattern is to pair the WebView UI with a custom-function backend that runs Node.js code (GraphQL queries, third-party API calls, business logic). The web side calls the backend at:

```text
${apiUrl}/function/{defId}/mex/{path}
```

…where `apiUrl` comes from `getAuthenticationInfo()`, `defId` comes from `upload_config.json`, and `{path}` is whatever path the backend handler registers. Authenticate with the bearer token. Full pattern in [Authentication & API](./references/authentication-and-api.md).

If you also need to **author** the backend (write the handlers, GraphQL queries, etc.), use the **`mex-custom-function-builder`** skill in this plugin — the MEXWEX skill only covers calling endpoints.

## Best practices

- **Keep the bundle small.** WebViews boot faster with smaller HTML. Tree-shake imports, lazy-load heavy screens behind navigation.
- **Use Breeze UI before custom CSS.** Breeze tokens give you correct mobile typography, spacing, and dark-mode behaviour. Hand-rolled styles drift.
- **Treat `getAuthenticationInfo()` as fresh-on-call.** Cache lightly (per render), not for the whole session.
- **Show progress on long calls.** Bridge methods that hit native pickers or remote APIs can take seconds. Use Breeze `Button loading` and `Alert` to surface state.
- **Use the template's Dev Mode for iteration.** `npm run dev` boots a built-in Dev Mode that proxies `mexBridge.*` to a real-backend-backed mock so you get real data, real save behaviour, and a viewport-locked iframe (iPhone 13 / iPad Air 11" toggle) — no hand-rolled mock fallbacks needed. Use `npm run dev:real-bridge` when you need to test against the actual native bridge. See [Project Setup → Local development loop](./references/project-setup.md).
- **Guard against double-submit.** Disable buttons while a request is in flight; replays cause duplicate writes.
- **Always send `sendExtensionMandatoryStatus(true)` once form requirements are satisfied** — the host save button is otherwise dimmed.
- **Avoid putting CRUD-relevant data in `instanceFetch.json`.** In MEXWEX you control your own data flow; the offline preload mechanism is bypassed. An empty `{}` is fine.
- **Match `defId` everywhere.** `upload_config.json.defId` is part of the URL when calling your custom-function backend (`/function/{defId}/mex/...`). A mismatch routes calls to a different form.
- **NEVER read implementation details from third-party wikis or unofficial blog posts** when authoring a MEXWEX form. Use this skill and the official `@skedulo/mexwex-bridge` package types as the source of truth. Wikis go stale.
