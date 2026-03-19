# Skedulo Agent Skills

Agent skills for building on the [Skedulo Pulse Platform](https://www.skedulo.com/). These skills extend AI coding assistants with Skedulo-specific domain knowledge, workflows, and guardrails.

## Skills

| Skill | Description | Use when | Install |
|-------|-------------|----------|---------|
| [skedulo-cli](skills/skedulo-cli/) | Safe, effective usage of the Skedulo CLI (`sked`) | Running any `sked` command, deploying packages, switching tenants, working with platform artifacts, or performing destructive operations | `npx skills add Skedulo/agent-skills@skedulo-cli` |
| [skedulo-api-developer](skills/skedulo-api-developer/) | Expert patterns for building solutions with Skedulo Pulse APIs | Working with `@skedulo/pulse-solution-services`, writing GraphQL queries/mutations, EQL syntax, batch operations, or optimizing API performance | `npx skills add Skedulo/agent-skills@skedulo-api-developer` |
| [connected-function-developer](skills/connected-function-developer/) | Build, modify, and deploy Skedulo custom functions | Creating serverless APIs, implementing custom business logic, or building third-party integrations on the Pulse Platform | `npx skills add Skedulo/agent-skills@connected-function-developer` |
| [optimization-extension-developer](skills/optimization-extension-developer/) | Build, modify, and deploy Skedulo Optimization Extensions | Adding custom logic to the optimization engine, filtering jobs/resources, applying constraints, or transforming optimization data | `npx skills add Skedulo/agent-skills@optimization-extension-developer` |

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
