# Project Setup

How to scaffold, configure, and iterate on a MEXWEX form.

## Scaffold with `sked mex template sync-mexwex` — required

**Always start a new MEXWEX project by running the `sked` CLI's Copier template.** This is the only sanctioned scaffolding path. Hand-rolling the `mexwex/` web app, `vite.config.js`, `package.json`, or the `mex_definition/` files is not supported — they drift from the host runtime, miss the single-file Vite config, and pin the wrong bridge version.

```bash
# From the parent directory where the form folder should live:
mkdir <form-id> && cd <form-id>
sked mex template sync-mexwex
```

What the command does:

- Runs Copier against the official MEXWEX template.
- Prompts for the project name (and any other template variables).
- Writes the canonical layout: `mexwex/` web app (React + Vite + `vite-plugin-singlefile`), `mex_definition/` with `ui_def.json` set to `{ "type": "mexwex" }`, `upload_config.json`, and a demo page exercising the bridge SDK.
- Pins the exact `@skedulo/mexwex-bridge` version compatible with the current host app.

### Useful flags

```bash
# Target a specific folder (defaults to ./)
sked mex template sync-mexwex --folder ./<form-id>

# Skip prompts, accept defaults (use only if every template variable already has a sensible default)
sked mex template sync-mexwex --non-interactive
```

### Re-running on an existing project

`sked mex template sync-mexwex` is **safe to re-run**. Copier merges template changes into an existing project and re-prompts for any answer it does not have stored. Run it again whenever:

- A new bridge version ships and the template's pinned version changes.
- The Vite / build config in the template is updated.
- You want to pull in new template files (e.g., a new boilerplate page).

After the merge, review the diff with `git status` / `git diff` and resolve any conflicts the same way you would for a normal merge.

### Prerequisites

- `sked` CLI installed (`sked --version` should print).
- Node.js ≥ 22 (the template's `engines` field).
- Copier — the CLI installs it on demand if missing.

After scaffolding you have the structure shown in `SKILL.md`. Open `mexwex/` in your editor and treat it as a normal React project. Customise `App.jsx`, add pages under `src/`, and edit `mex_definition/metadata.json` to set the form's `contextObject` (`Jobs` / `Shifts` / `Resources`).

## `mexwex/package.json` — required dependencies

```json
{
  "name": "<project_name>",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "dev:real-bridge": "cross-env VITE_REAL_BRIDGE=1 vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview",
    "typecheck": "tsc -b --noEmit"
  },
  "dependencies": {
    "@skedulo/breeze-ui": "^1.31.2",
    "@skedulo/breeze-ui-react": "^1.31.2",
    "@skedulo/mexwex-bridge": "0.0.5",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.1.1",
    "cross-env": "^7.0.3",
    "vite": "^7.3.1",
    "vite-plugin-singlefile": "^2.3.0",
    "typescript": "^5.9.3"
  },
  "engines": {
    "node": ">=22"
  }
}
```

Pin `@skedulo/mexwex-bridge` to an exact version — the bridge protocol is versioned and the host app expects a specific compatible release. The template pins it for you when you scaffold; do not bump independently.

The two `dev` scripts pick which bridge implementation the form talks to at runtime — see **Local development loop** below.

You can add other libraries (Zustand for state, date-fns, your own UI primitives) — but keep an eye on bundle size. The output is loaded by a mobile WebView on every form open.

## `mexwex/vite.config.js`

The native WebView loads the build output as a file URI. Browsers do not resolve sibling JS / CSS files reliably from that URI, so the entire bundle must inline into a single HTML file.

```javascript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  plugins: [react(), viteSingleFile()],
  server: {
    port: 3000,
    host: true,
  },
})
```

`viteSingleFile()` tells Vite to inline JS, CSS, and small assets directly into `dist/index.html`. After `npm run build` you should see one file in `dist/` — that is what the platform serves.

## `mexwex/src/main.jsx`

```jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@skedulo/breeze-ui'   // Breeze UI design tokens + base CSS — import once at the root
import App from './App.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
```

The `@skedulo/breeze-ui` import (the non-React side) installs the CSS custom properties and base styles that `@skedulo/breeze-ui-react` components rely on.

## `upload_config.json`

```json
{
  "name": "Your Form Name",
  "defId": "your_form_def_id",
  "engineVersion": "1.0.0"
}
```

`defId` is the form identifier. It also appears in the URL when calling your custom-function backend (`/function/{defId}/mex/...`), so keep it consistent and stable. Use snake_case.

## `mex_definition/` — minimal files

```text
mex_definition/
├── ui_def.json         # { "type": "mexwex" }
├── metadata.json       # { "contextObject": "Jobs", ... }
├── instanceFetch.json  # {}  — empty unless you want pre-loaded data
├── staticFetch.json    # {}
└── static_resources/
    └── locales/en.json # {} — bridge.getLocalizedString() reads this on demand
```

`instanceFetch.json` and `staticFetch.json` may stay empty for a fully API-driven form. If you put queries in them, the platform pre-fetches and exposes the result via `getInstanceData()` / `getStaticData()`. For most MEXWEX forms it's cleaner to fetch directly from your APIs in the web app.

## Local development loop

The scaffolded template ships **two dev modes**. Pick the one that matches what you're verifying.

### Mode 1: `npm run dev` — Dev Mode (default)

Iterate on UI, layout, and form logic in a desktop browser. No native shell, no device required.

```bash
cd mexwex
npm run dev
```

Vite serves the form on `http://localhost:3000`. The form renders inside a **viewport-locked iframe** so you're forced to design for real device widths from the start. The page chrome around the iframe is the Dev Panel.

**First run** — paste credentials.

Bridge calls need a real access token + tenant context. On first run you'll see a Dev Mode landing screen asking for:

- **Access token** — paste a token from your Skedulo tenant. Must have the mobile permission set the platform expects for MEX forms.
- **Environment** — DEV or Prod (per region).
- **Form context** — Job / Shift / Global Form.
- **Context UID** — the parent record's UID (Job UID, Shift UID); auto-resolved from the token's `resource_id` claim for Global Forms.

Credentials are saved to `localStorage` and persist across reloads.

**Viewport simulation.**

The iframe renders at one of two device presets, toggleable from the Dev Menu:

| Preset | Dimensions (W × H) |
|---|---|
| iPhone 13 (default) | 390 × 844 |
| iPad Air 11" | 834 × 1194 |

**By default the iframe renders at the real device dimensions** so `window.innerWidth` and media queries inside the form fire at exactly the values above. The form is tested at honest device pixels. If the iframe overflows your laptop screen, the surrounding backdrop scrolls — your form is always reachable.

**"Fit viewport height" toggle.** Below the device toggle you'll find a checkbox: when on, the iframe is scaled to fill your laptop's vertical space, with the width derived from the device aspect ratio. Useful on 13"–16" laptops where 844 px (iPhone) or 1194 px (iPad) doesn't fit. A warning is shown inline because the form sees the *scaled* size, not the real device dimensions — `window.innerWidth` and media queries fire at the rendered size. Use this for visual layout work; turn it off when you need to verify exact device-pixel behaviour. The preference persists across reloads.

Use **Fast Refresh** from the menu if you want a clean mount after switching presets or toggling fit mode.

**Dev Menu** — open with `⌘⇧D` / `Ctrl+Shift+D` or click the environment chip.

| Action | What it does |
|---|---|
| Viewport toggle | Switch between iPhone 13 and iPad Air 11" — live resize, no reload. |
| Refresh | Full upstream data refresh — clears in-memory cache. |
| Fast Refresh | Reload the iframe — fresh mount at the current viewport. |
| Troubleshoot form's metadata | Inspect why a `showIf` / `mandatoryIf` rule is firing. |
| Clear credentials | Reset to the Dev Mode landing screen. |

**What `mexBridge.*` does in this mode.**

Bridge calls route to a mock implementation that proxies to the real Skedulo backend using your pasted token — so `getInstanceData`, `getStaticData`, `getMetadata`, `saveInstanceData`, and GraphQL queries all hit live data. Hardware-only methods (`captureAttachments`, `captureSignature`) return rotating placeholder images; their upload paths still go to the real Skedulo Files API so file UIDs and download URLs are genuine.

This means you can build a complete MEXWEX form and verify save / load against live records without ever booting the mobile app.

### Mode 2: `npm run dev:real-bridge` — connect to the mobile shell

Use this mode when you need to verify end-to-end behaviour against the real bridge running inside the Skedulo Plus mobile app (native modules, hardware capture, payment flows, push notifications).

```bash
cd mexwex
npm run dev:real-bridge
```

The Vite server boots on the same port (3000) but the Dev Panel and viewport iframe are skipped. The form renders full-screen as if it were the production bundle, and every `mexBridge.*` call goes to the real `@skedulo/mexwex-bridge` SDK — no mocking.

On the mobile shell side, enable the dev-only flag that points the in-app WebView at your machine's IP (`http://<your-machine-ip>:3000`). Hot reload works end-to-end, with the real bridge mediating data and hardware. The exact toggle is host-app specific — see your team's MEX dev runbook.

### Quick reference

| You want to… | Run |
|---|---|
| Iterate fast on UI + form logic | `npm run dev` |
| Test responsive layout on a wider screen | `npm run dev` → Dev Menu → iPad Air 11" |
| Save real data, hit real APIs | `npm run dev` (Dev Mode already proxies to real backend) |
| Verify a native module / hardware call | `npm run dev:real-bridge` + dev WebView on device |
| Smoke-test the production bundle locally | `npm run build && npm run preview` |

## Build for upload

```bash
cd mexwex
npm run build
```

Produces `mexwex/dist/index.html` — a single self-contained HTML file. The platform packages this with the `mex_definition/` files and uploads to Skedulo. Verify the file is one HTML file (no separate `assets/` folder) before uploading.

## Shipping

Use the `sked` CLI to upload the built form:

```bash
sked mex upload   # exact command may vary — see `sked mex --help`
```

Upload increments the form revision; users get the new bundle on next open.