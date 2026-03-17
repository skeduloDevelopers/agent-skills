# Skedulo Agent Skills

Agent skills for building on the [Skedulo Pulse Platform](https://www.skedulo.com/). These skills extend AI coding assistants with Skedulo-specific domain knowledge, workflows, and guardrails.

## Skills

| Skill | Description | Use when | Install |
|-------|-------------|----------|---------|
| [skedulo-cli](skills/skedulo-cli/) | Safe, effective usage of the Skedulo CLI (`sked`) | Running any `sked` command, deploying packages, switching tenants, or working with platform artifacts | `npx skills add Skedulo/agent-skills@skedulo-cli` |

## Installation

Install a skill into your project using the [Skills CLI](https://skills.sh/):

    npx skills add Skedulo/agent-skills@<skill-name>

This injects the skill into your project's agent config file (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`, etc.) based on your AI platform. Once installed, your agent will automatically know when to use the skill.

## Contributing

To add a new skill, create a directory under `skills/` with a `SKILL.md` and an `AGENTS.md`:

    skills/
      my-new-skill/
        SKILL.md       # Required — skill rules, workflows, and domain knowledge
        AGENTS.md      # Required — trigger conditions and agent-facing context

See the [Skills documentation](https://skills.sh/) for authoring guidelines.
