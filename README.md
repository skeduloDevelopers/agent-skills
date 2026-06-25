# Skedulo Agent Skills

Agent skills for building on the [Skedulo Pulse Platform](https://www.skedulo.com/). These skills extend AI coding assistants with Skedulo-specific knowledge, workflows, and best practices.

## Installation

Install individual skills using the [Skills CLI](https://skills.sh/):

```bash
npx skills add Skedulo/agent-skills@<skill-name>
```

## Available Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [skedulo-cli](skills/skedulo-cli/) | Safe, effective usage of the Skedulo CLI (`sked`), covering alias enforcement, `--help` proactivity, `--json` inspection, and destructive operation guardrails | `npx skills add Skedulo/agent-skills@skedulo-cli` |
| [skedulo-api-developer](skills/skedulo-api-developer/) | Expert patterns for building solutions with Skedulo Pulse APIs, covering `@skedulo/pulse-solution-services`, GraphQL, EQL, batch operations, and performance optimization | `npx skills add Skedulo/agent-skills@skedulo-api-developer` |
| [connected-function-developer](skills/connected-function-developer/) | Build, modify, and deploy Skedulo custom functions: serverless APIs for custom business logic and third-party integrations on the Pulse Platform | `npx skills add Skedulo/agent-skills@connected-function-developer` |
| [optimization-extension-developer](skills/optimization-extension-developer/) | Build, modify, and deploy Skedulo Optimization Extensions: custom business logic for filtering, constraining, and transforming optimization data | `npx skills add Skedulo/agent-skills@optimization-extension-developer` |
| [triggered-actions-developer](skills/triggered-actions-developer/) | Author, edit, and deploy Triggered Actions: event-driven automations that fire on object INSERT/UPDATE/DELETE, platform events, and deferred timers (`call_url` / `send_sms`) | `npx skills add Skedulo/agent-skills@triggered-actions-developer` |
| [webhooks-developer](skills/webhooks-developer/) | Author, edit, and deploy Webhooks: scheduled (cron) execution and inbound-SMS handling — the event automations Triggered Actions can't cover | `npx skills add Skedulo/agent-skills@webhooks-developer` |
| [automations-developer](skills/automations-developer/) | Create, edit, and deploy Pulse automations via the Automations REST API, covering the action/trigger vocabulary, schema corrections, and workflow patterns | `npx skills add Skedulo/agent-skills@automations-developer` |
| [object-models-developer](skills/object-models-developer/) | Define, edit, review, and deploy Pulse object models: custom objects, custom fields on standard objects, lookups, picklists, and constraint-based validation | `npx skills add Skedulo/agent-skills@object-models-developer` |
| [user-role-developer](skills/user-role-developer/) | Define, edit, review, and deploy Pulse user roles: permission-pattern sets (glob keys) that control what a user can do | `npx skills add Skedulo/agent-skills@user-role-developer` |
| [horizon-page-developer](skills/horizon-page-developer/) | Author and deploy Skedulo Horizon platform pages: HorizonPage / HorizonTemplate schemas and the three page authoring flows (Page Builder, Custom Page Builder, Direct Nunjucks) | `npx skills add Skedulo/agent-skills@horizon-page-developer` |
| [horizon-list-config-developer](skills/horizon-list-config-developer/) | Author and deploy HorizonListConfig artifacts that configure built-in Skedulo object list pages, covering the JSON schema, column templates, and deploy commands | `npx skills add Skedulo/agent-skills@horizon-list-config-developer` |
| [page-builder-column-templates](skills/page-builder-column-templates/) | Complete guide to Skedulo Page Builder list view column templates, covering template syntax, styling, date/timezone formatting, number/currency, picklists, conditionals, and cross-object fields | `npx skills add Skedulo/agent-skills@page-builder-column-templates` |
| [mex-developer](skills/mex-developer/) | Build, modify, and validate Mobile Extensions (MEX) for Skedulo Plus: JSON-configured mobile UIs with integrated data fetching and logic | `npx skills add Skedulo/agent-skills@mex-developer` |
| [mex-custom-function-builder](skills/mex-custom-function-builder/) | Add server-side custom functions to MEX forms: fetch / save / validate / static handlers, atomic multi-object saves, and remote validation | `npx skills add Skedulo/agent-skills@mex-custom-function-builder` |
| [mexwex-developer](skills/mexwex-developer/) | Build, modify, and validate MEXWEX forms: WebView-based mobile forms that talk to the native shell via the `@skedulo/mexwex-bridge` SDK | `npx skills add Skedulo/agent-skills@mexwex-developer` |

## Contributing

To add a new skill, create a directory under `skills/` with a `SKILL.md` and an `AGENTS.md`:

```
skills/
  my-new-skill/
    SKILL.md              # Required — skill rules, workflows, and domain knowledge
    AGENTS.md             # Required — trigger conditions and agent-facing context
    supporting-file.md    # Optional — heavy reference or supporting material
```

See the [Skills documentation](https://skills.sh/) for authoring guidelines.

## Resources

- [Skedulo Developer Documentation](https://docs.skedulo.com/)
- [Skedulo CLI Examples](https://github.com/skeduloDevelopers/SkeduloCLIExamples)
- [Skills CLI](https://skills.sh/)
