# Skedulo Agent Skills

Agent skills for building on the [Skedulo Pulse Platform](https://www.skedulo.com/). These skills extend AI coding assistants with Skedulo-specific domain knowledge, workflows, and guardrails.

## Skills

| Skill | Description | Use when | Install |
|-------|-------------|----------|---------|
| [skedulo-cli](skills/skedulo-cli/) | Safe, effective usage of the Skedulo CLI (`sked`) | Running any `sked` command, deploying packages, switching tenants, working with platform artifacts, or performing destructive operations | `npx skills add Skedulo/agent-skills@skedulo-cli` |
| [skedulo-api-developer](skills/skedulo-api-developer/) | Expert patterns for building solutions with Skedulo Pulse APIs | Working with `@skedulo/pulse-solution-services` / `@skedulo/pulse-solutions-framework`, writing GraphQL or EQL, batch operations, or optimizing API performance | `npx skills add Skedulo/agent-skills@skedulo-api-developer` |
| [connected-function-developer](skills/connected-function-developer/) | Build, modify, and deploy Skedulo custom functions | Creating serverless APIs, implementing custom business logic, or building third-party integrations on the Pulse Platform | `npx skills add Skedulo/agent-skills@connected-function-developer` |
| [optimization-extension-developer](skills/optimization-extension-developer/) | Build, modify, and deploy Skedulo Optimization Extensions | Adding custom logic to the optimization engine, filtering jobs/resources, applying constraints, or transforming optimization data | `npx skills add Skedulo/agent-skills@optimization-extension-developer` |
| [triggered-actions-developer](skills/triggered-actions-developer/) | Author, edit, and deploy Triggered Actions | Automating on object INSERT/UPDATE/DELETE, platform events, or deferred timers via `call_url` / `send_sms` | `npx skills add Skedulo/agent-skills@triggered-actions-developer` |
| [webhooks-developer](skills/webhooks-developer/) | Author, edit, and deploy Webhooks | Needing scheduled (cron) execution or inbound-SMS handling — automations Triggered Actions can't cover | `npx skills add Skedulo/agent-skills@webhooks-developer` |
| [automations-developer](skills/automations-developer/) | Create, edit, and deploy Pulse automations via the Automations REST API | Authoring/editing an automation, debugging a 400/500 from the Automations API, or translating a webhook/triggered-action into the automation platform | `npx skills add Skedulo/agent-skills@automations-developer` |
| [object-models-developer](skills/object-models-developer/) | Define, edit, review, and deploy Pulse object models | Modelling custom objects, custom fields on standard objects, lookups, picklists, or constraint-based validation rules | `npx skills add Skedulo/agent-skills@object-models-developer` |
| [user-role-developer](skills/user-role-developer/) | Define, edit, review, and deploy Pulse user roles | Designing or editing permission sets / roles, or auditing what a user can do | `npx skills add Skedulo/agent-skills@user-role-developer` |
| [horizon-page-developer](skills/horizon-page-developer/) | Author and deploy Skedulo Horizon platform pages | Building Horizon pages via Page Builder, Custom Page Builder, or Direct Nunjucks (HorizonPage / HorizonTemplate) | `npx skills add Skedulo/agent-skills@horizon-page-developer` |
| [horizon-list-config-developer](skills/horizon-list-config-developer/) | Author and deploy HorizonListConfig artifacts | Configuring built-in Skedulo object list pages — columns, Nunjucks templates, and list config | `npx skills add Skedulo/agent-skills@horizon-list-config-developer` |
| [page-builder-column-templates](skills/page-builder-column-templates/) | Skedulo Page Builder list view column templates | Writing or styling list-view column templates — Nunjucks, lozenges/links, date/number/currency formatting, picklists, conditionals, cross-object fields | `npx skills add Skedulo/agent-skills@page-builder-column-templates` |
| [mex-developer](skills/mex-developer/) | Build, modify, and validate Mobile Extensions (MEX) for Skedulo Plus | Building or editing JSON-configured MEX mobile forms with integrated data fetching and logic | `npx skills add Skedulo/agent-skills@mex-developer` |
| [mex-custom-function-builder](skills/mex-custom-function-builder/) | Add server-side custom functions to MEX forms | Implementing fetch/save/validate/static handlers, atomic multi-object saves, server-side aggregates, or remote validation in a MEX form | `npx skills add Skedulo/agent-skills@mex-custom-function-builder` |
| [mexwex-developer](skills/mexwex-developer/) | Build, modify, and validate MEXWEX (WebView) forms | `ui_def.json` is `{ "type": "mexwex" }`, a `mexwex/` folder exists, or building a WebView form that calls live APIs via `@skedulo/mexwex-bridge` | `npx skills add Skedulo/agent-skills@mexwex-developer` |

## Installation

Install a skill into your project using the [Skills CLI](https://skills.sh/):

    npx skills add Skedulo/agent-skills@<skill-name>

This injects the skill into your project's agent config file (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`, etc.) based on your AI platform. Once installed, your agent will automatically know when to use the skill.

## Contributing

To add a new skill, create a directory under `skills/` with a `SKILL.md` and an `AGENTS.md`:

    skills/
      my-new-skill/
        SKILL.md              # Required — skill rules, workflows, and domain knowledge
        AGENTS.md             # Required — trigger conditions and agent-facing context
        supporting-file.md    # Optional — heavy reference or supporting material

See the [Skills documentation](https://skills.sh/) for authoring guidelines.
