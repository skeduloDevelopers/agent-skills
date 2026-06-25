# Review Checklist

Run this before deploying a MEXWEX form. Each item is a yes / no — if no, fix before shipping.

## Project files

```text
- [ ] `mex_definition/ui_def.json` is exactly `{ "type": "mexwex" }`. No extra keys.
- [ ] `upload_config.json` has `name`, `defId`, `engineVersion`. `defId` is snake_case and matches what the custom-function backend expects (`/function/{defId}/mex/...`).
- [ ] `metadata.json` has the right `contextObject` (`Jobs`, `Resources`, or `Shifts`). `contextObjectId` from `getMetadata()` will be a record of this type.
- [ ] `instanceFetch.json` and `staticFetch.json` are either empty `{}` or only contain queries you actively use. Don't preload data you don't read.
- [ ] `static_resources/locales/en.json` exists (even if empty `{}`).
```

## Web bundle

```text
- [ ] `mexwex/package.json` pins `@skedulo/mexwex-bridge` to a specific version. Bridge is versioned with the host app — don't use `^` ranges.
- [ ] `mexwex/vite.config.js` includes `viteSingleFile()` from `vite-plugin-singlefile`.
- [ ] `npm run build` produces a single `mexwex/dist/index.html` — no separate `assets/` folder.
- [ ] No `console.log` left in production code that leaks PII or tokens.
- [ ] No hardcoded API tokens, API URLs, or third-party secret keys in the bundle. Tokens come from `getAuthenticationInfo()`; URLs are derived from `apiUrl`.
- [ ] No `localhost` references in production code paths. Local-dev fallbacks are gated on `import.meta.env.DEV` or similar.
```

## Bridge usage

```text
- [ ] Every `mexBridge.*` call is wrapped in `try / catch`.
- [ ] `getAuthenticationInfo()` is called fresh on each API call, not cached for the whole session.
- [ ] `captureSignature` and `captureAttachments` aren't wrapped in your own timeouts — they have no SDK timeout for a reason.
- [ ] Form calls `saveInstanceData()` before `exit()` if there are unpersisted changes.
- [ ] Form calls `sendExtensionMandatoryStatus(true / false)` whenever required-field state changes. Without this, the host save button is dimmed.
- [ ] Form calls `mexBridge.exit()` from the back-from-root handler — never `window.history.back()` past the initial route.
- [ ] No invented bridge methods or parameters. Every call matches the `bridge-api.md` reference.
```

## Lifecycle

```text
- [ ] Initial load shows a loading state until metadata + first data fetch resolve. No flash of empty UI.
- [ ] Failed initial load shows an error screen with a retry button — not a blank white WebView.
- [ ] Long-running operations (Tap-to-Pay, file uploads, payment confirms) disable their trigger button and show progress feedback.
- [ ] Same-operation double-tap is prevented — buttons go `disabled` while their handler is in flight.
- [ ] Android hardware back is wired up via `window.onNativeBackPress` — the navigation provider does this for you. Test on Android.
```

## API & auth

```text
- [ ] All authenticated `fetch` calls send `Authorization: Bearer ${accessToken}` and `Content-Type: application/json` (for JSON bodies).
- [ ] Custom-function URLs use the `${apiUrl}/function/{defId}/mex/{path}` shape. The `{defId}` matches `upload_config.json`.
- [ ] No secret keys in the bundle. Stripe / OpenAI / etc. secrets stay on the custom-function backend.
- [ ] Writes that must not duplicate (payments, record creates) include an idempotency mechanism.
- [ ] Auth errors (401 / 403) surface to the user with actionable text — not just "Failed".
- [ ] **GraphQL write inputs are strictly scoped.** Every field in the upsert/insert/update input is either (a) explicitly listed as writable in the requirements, (b) `UID` for an update, or (c) a foreign key needed to establish the relationship. No "helpful" extras (`Name` copied from a lookup, computed totals, audit fields). When in doubt, drop the field and ask — silent writes to read-only fields may be rejected, or worse, accepted and corrupt server-managed state.
- [ ] **GraphQL SELECT sets are strictly scoped.** Every field fetched is one you actually display or branch on. Don't fetch denormalised audit fields or "just in case" columns.
- [ ] **GraphQL filter variables use the entity's typed scalar** (`EQLQueryFilter<Entity>`), not `String!`. Filter string is built in JavaScript; never embed `$var` inside a quoted filter literal.
```

## Attachments & signatures

```text
- [ ] Capture and persist are split — captures can be discarded before `addAttachments` / `addSignature`.
- [ ] Every persist call includes `parentContextId` (usually `metadata.contextObjectId`).
- [ ] Authenticated images use the `AuthImage` blob pattern — not bare `<img src={downloadURL}>`.
- [ ] `URL.revokeObjectURL` is called on `AuthImage` unmount.
```

## UI & navigation

```text
- [ ] Header respects `env(safe-area-inset-top)` so iOS notch / Dynamic Island doesn't overlap.
- [ ] Page container clamps `overscrollBehavior: 'none'` — no rubber-band scrolling.
- [ ] All buttons / inputs come from `@skedulo/breeze-ui-react`, not hand-rolled.
- [ ] `<GlobalStyles>` wraps the app once; `@skedulo/breeze-ui` CSS is imported once at the root in `main.jsx`.
- [ ] Tap targets are at least 44×44 px (Breeze defaults already meet this).
- [ ] Form is usable with VoiceOver (iOS) and TalkBack (Android) — quick smoke-test before ship.
```

## Performance

```text
- [ ] Bundle size is reasonable. Inspect `dist/index.html` size; if it crosses ~1 MB, audit imports for tree-shaking opportunities.
- [ ] Heavy screens are lazy-loaded behind navigation, not eager-loaded at boot.
- [ ] No infinite re-render loops. Run with React StrictMode (`<StrictMode>` in `main.jsx`) and check the console.
```

## Localisation

```text
- [ ] User-visible strings come from `getLocalizedString` or your own i18n layer — not raw inline text — if the form ships in multiple languages.
- [ ] Fallback strings exist for every locale key, in case a translation is missing.
```

## Dev to prod

```text
- [ ] Dev fallbacks for `getAuthenticationInfo`, `getMetadata`, and any `contextObjectId` are gated on a dev flag and stripped at build.
- [ ] No dev API URLs in production paths.
- [ ] Bundle has been tested on a real device (iOS and Android), not just in the desktop browser dev server.
```

## Final check

Open the form on device and walk through the happy path. Then walk through:

- Network off mid-flow.
- Pressing back at every screen.
- Force-quit and re-open — does state restore?
- Filling in everything, saving, exiting, re-opening — does the data survive?
- For payment / write flows: double-tap the action button — no duplicate effect.

If all pass, ship.
