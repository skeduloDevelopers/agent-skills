# When to use MEXWEX vs Standard MEX

Skedulo Mobile Extensions has two rendering modes. Choose carefully — switching modes mid-build is expensive.

## Use Standard MEX when…

- The form is a **CRUD form on Skedulo data** (Jobs, Resources, Shifts, Job Products, etc.).
- You want **offline support out of the box** — Standard MEX pre-fetches and caches data so users can keep working without connectivity, then syncs on save.
- Your UI is composable from **standard editor / display components** (text, select, date, toggle, sections, lists).
- You want the platform to handle **page navigation, validation chrome, mandatory indicators, save / discard buttons** for you.
- The form sits on a list page with **standard search and filter** behaviour.

If you can build the form by writing JSON only, prefer Standard MEX. See the `mex-developer` skill.

## Use MEXWEX when…

- The form is **API-driven** — it calls live endpoints on every interaction rather than working off a pre-loaded snapshot.
- You're integrating a **third-party SDK** that has no equivalent in Standard MEX (Stripe Terminal, mapping, charts, signature pads with bespoke flows, barcode scanners with custom UI).
- The UX is **bespoke** in a way Standard MEX can't express: custom layouts, animations, multi-step wizards with custom transitions, real-time data displays.
- You need **full control over data flow** — what's fetched, when, with what shape, how errors are handled.
- The form is fundamentally **online**: the user must be connected for it to function (e.g. Tap-to-Pay, live inventory check, dispatcher chat).

## Decision shortcuts

| Question | Answer → Mode |
|---|---|
| "Does the user need to fill this out offline?" | Yes → Standard. No → Either. |
| "Is the data exclusively from Skedulo's GraphQL?" | Yes → Standard (offline) or Standard with online mode. No → MEXWEX. |
| "Does the form embed a third-party SDK?" | Yes → MEXWEX. |
| "Does the design look like a normal Skedulo form?" | Yes → Standard. Looks bespoke → MEXWEX. |
| "Is this a payment, real-time integration, or live dashboard?" | Almost certainly → MEXWEX. |

## Hybrid: Standard MEX with Online Only Mode

Standard MEX has its own **Online Only Mode** (`settings.fullOnlineMode: true`) that swaps the offline cache for live API queries while keeping the JSON-driven UI. If you need live data but the UI fits the standard component set, this is usually the right midpoint — see the `mex-developer` skill's `references/online-mode.md`.

Choose MEXWEX over Standard-online-mode only when the **UI** also needs to be bespoke. Live data alone is not a reason to drop the JSON UI.

## Common mistakes

- **Picking MEXWEX because "it's more flexible"** — flexibility costs build time, bundle size, and maintenance. Standard MEX is cheaper when it fits.
- **Picking Standard MEX for an inherently online flow** — you'll fight the offline cache, hit `instanceFetch.json` limits, and end up wedging custom buttons in everywhere. Switch to MEXWEX or Standard online mode early.
- **Splitting one logical form across both modes** — a MEXWEX form and a Standard MEX form are different deployments with different contexts. If you find yourself wanting to do this, the form should probably be one MEXWEX form with internal navigation.
