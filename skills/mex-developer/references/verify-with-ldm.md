# Verify a form at runtime with Low-code Local Development Mode (LDM)

**Audience: you, the coding agent.** After you build or edit a standard `ui_def` MEX form, JSON validity is not proof it works. Expressions, data fetches, `showIf`/`mandatoryIf` rules, validators, online queries, and save payloads only reveal their real behaviour when the form actually *runs* against a Skedulo tenant. LDM is a local browser app that renders and debugs a standard `ui_def` form against a real tenant, with an inspector that exposes the live state, network traffic, and form logic. Use it to **confirm a form works before you tell the developer it's done** — and to diagnose it when it doesn't.

LDM renders standard (`ui_def`) forms only. It does not render MEXWEX (web-app) forms.

> **Never fake verification.** If you cannot get a valid token (see Credentials), or the app cannot reach the tenant, **stop and ask the developer** for working credentials. Do not substitute mock data, assume the form works, or report success you did not observe.

---

## 1. Install the LDM app

Run from the directory that **contains** the form folder(s) you want to test (so the app lands beside them):

```bash
sked mex template lowcode-ldm -o ldm_lowcode
```

This downloads a self-contained browser app into `./ldm_lowcode`. It overwrites itself on every run, so re-running just refreshes it to the latest version — your form folders live outside it and are never touched.

Boot it:

```bash
cd ldm_lowcode
npm install
npm run dev          # serves on http://localhost:3100
```

By default the app lists the form folders that are **siblings** of `ldm_lowcode` (its parent directory). If your forms live elsewhere, point the app at them:

```bash
LDM_FORMS_ROOT="/absolute/path/to/forms" npm run dev
```

---

## 2. Credentials — set these up so you can verify unattended

The LDM app authenticates through its **login screen** (you pick an Environment and paste an access token). It does **not** read credentials from a file on its own. So to verify without a human babysitting each step, agree on a credentials file the developer fills in and you read.

Ask the developer to create a `.env` in the **form folder** (the one with `mex_definition/`):

```bash
# .env — in the form folder. NEVER commit this; add it to .gitignore.
LDM_ENVIRONMENT=DEV        # DEV or Prod
LDM_REGION=                # required only when LDM_ENVIRONMENT=Prod (e.g. US, AU, EU, UK)
LDM_ACCESS_TOKEN=          # a Skedulo access token for that tenant (a bearer token, as used for Skedulo API calls)
LDM_CONTEXT_UID=           # optional: a specific Job/Shift UID to open the form against; leave blank to auto-pick the latest
```

Rules you must follow:

- **Treat `LDM_ACCESS_TOKEN` as a secret.** Confirm the file is git-ignored. Never print the token, never paste it into a commit, a log, an issue, or a chat transcript.
- If `LDM_ACCESS_TOKEN` is missing or empty, **ask the developer to fill it in** before continuing — do not guess or proceed.
- Access tokens are short-lived. If verification fails with a `401`/auth error, the token has likely expired — ask the developer for a fresh one rather than retrying.

You read those values and feed them into the LDM login on the developer's behalf.

---

## 3. Drive the verification

Use whatever browser-automation capability you have (e.g. a Playwright MCP server, or the Playwright CLI you install into a scratch folder) to drive the running app. The login is a single page; fill it top to bottom using the values from `.env`:

1. Open `http://localhost:3100`.
2. **Skedulo environment** — choose `DEV` or `Prod` to match `LDM_ENVIRONMENT`. (A Region selector appears only for `Prod`; set it from `LDM_REGION`.)
3. **Access token** — paste `LDM_ACCESS_TOKEN`. Once it's accepted, the app validates your deployed forms in the background.
4. **Folder** — pick the folder of the form under test.
5. **Form** — pick the form. Invalid ones are disabled with a hover reason (not a standard low-code form, or **not deployed to this tenant** — deploy it first if so).
6. **Context** — for forms bound to a Job or Shift, the app auto-selects the most recent matching record; override with `LDM_CONTEXT_UID` if set.
7. Click **Open form**.

The form renders inside a phone-sized frame. Open the **Troubleshooting** panel with `Cmd/Ctrl + Shift + D` (or via the on-screen Dev Menu). The shortcuts `Cmd/Ctrl + Shift + 1/2/3/4` jump straight to the Observing Data / Network / UI Events / Metadata columns; `Esc` closes the panel.

If you have no browser-automation capability available, set up the `.env`, start the app, and hand the developer the exact steps above to run the check themselves — then act on what they report.

---

## 4. What the Troubleshooting panel exposes, and what to check

Each column answers a different "is the form actually doing the right thing?" question.

### Observing Data — the live state
Four tabs show exactly what the renderer is bound to right now, updating as you interact:
- **`formData`** — the instance record (what Save writes)
- **`sharedData`** — static/lookup data from `staticFetch.json`
- **`pageData`** — the current page's working data
- **`metadata`** — form-level config + the context record

Check: did `instanceFetch.json` / `staticFetch.json` actually populate these? Empty `formData` or `sharedData` when you expected values means a fetch query is wrong (bad `object`, `filter`, or missing `variables` block).

### Evaluate — test an expression against live data
A sandbox that runs any expression against the open page's context, using the same engine the form uses. Use it to confirm a `showIf`, `validator`, or binding resolves the way you intended *before* trusting it — e.g. evaluate `formData.JobDetails.Status == 'Complete'` and confirm the boolean. It also lists every function available in expressions.

### Network — every backend call
Records each request with method, status, duration, and full request/response bodies (the auth header is masked). Check: online queries return `200`; the request bodies carry the `filter`/`fields` you expect; nothing 4xx/5xx. This is where a broken online query or a malformed save shows up.

### UI Events — what the form is doing
A running log of in-form activity, filterable by type (the **Types** control). Four kinds:
- **Observer** — a data observer fired (the watched value changed and a handler ran)
- **Custom function** — a `cf.*` call, with its arguments, return value, and duration *(off by default — it fires on every render, so it's noisy; turn it on when debugging a custom function)*
- **Logs** — runtime warnings/errors the form raised. **Check this for errors first** — a thrown expression or failed query surfaces here.
- **Data** — every write the form sends (save / online upsert / delete), with the exact payload

Events that triggered a backend call carry a link to it: open the event and click **"Open request #N in the Network tab"** to jump straight to the matching request/response. Use this to confirm a save sent the record shape you expected.

### Metadata — `showIf` / `mandatoryIf` placement rules
Shows the form's `metadata.json` visibility/mandatory rules and evaluates them server-side against the connected record with a **Try** button (returns `true`/`false`). If a form "won't appear on a Job", this is almost always why — verify the `showIf` resolves `true` for your test record.

### Debug overlays — per-field rule state
Toggle **Debug overlays** in the panel header and every field shows chips for its `showIf` / `mandatoryIf` / `validator` rules (green = passing). Hidden fields announce themselves instead of silently vanishing. Double-click a chip to see the actual expression and **Test** it in the Evaluate sandbox. Use this to find a validator that's wrongly blocking save, or a `showIf` hiding a field you expected.

### Save / exit mandatory status
When the form is saved — and again when it's closed — LDM records a **Data** event capturing the form's mandatory "isCompleted" status (computed from `metadata.json`'s `mandatoryExpression`, when one is defined) alongside the instance data being sent. Check that this status matches your intent for whether the form should count as complete.

### Copy debug bundle
The **Copy debug bundle** button copies the whole picture — the form definition, live `formData`/`sharedData`/`pageData`, recent network calls (with bodies), and recent events — as Markdown to the clipboard. When a form misbehaves in a way you can't immediately explain, capture this bundle and reason over it (or hand it to the developer) instead of guessing.

---

## 5. Verification checklist

Treat a form as runtime-verified only when, in LDM:

- [ ] The form **renders** with no error screen and no `ui_def` problem banner.
- [ ] **Observing Data** shows `formData` / `sharedData` populated as the fetch queries intend.
- [ ] **UI Events → Logs** shows no runtime errors during a normal pass through the form.
- [ ] **Network** shows all backend calls returning success (no 4xx/5xx); online query bodies look right.
- [ ] Key **expressions** (`showIf`, `validator`, important bindings) resolve correctly in **Evaluate**.
- [ ] **Metadata** `showIf`/`mandatoryIf` evaluate as intended for the test record.
- [ ] A **save** produces a Data event whose payload is the correct record shape (right `object`, fields, and parent foreign key).
- [ ] For online forms: create / edit / delete each round-trip successfully (check the linked Network call).

Anything that fails here is a real defect to fix in the form's JSON — not a reason to lower the bar on what counts as "done".
