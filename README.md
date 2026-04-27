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
| [page-builder-column-templates](skills/page-builder-column-templates/) | Complete guide to Skedulo Page Builder list view column templates, covering template syntax, styling, date/timezone formatting, number/currency, picklists, conditionals, and cross-object fields | `npx skills add Skedulo/agent-skills@page-builder-column-templates` |

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
