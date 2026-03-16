# Skedulo Agent Skills

Agent skills for building on the [Skedulo Pulse Platform](https://www.skedulo.com/). These skills extend AI coding assistants with Skedulo-specific knowledge, workflows, and best practices.

## Installation

Install individual skills using the [Skills CLI](https://skills.sh/):

```bash
npx skills add Skedulo/agent-skills@skedulo-cli
```

## Available Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [skedulo-cli](skills/skedulo-cli/) | Safe, effective usage of the Skedulo CLI (`sked`) — alias enforcement, `--help` proactivity, `--json` inspection, and destructive operation guardrails | `npx skills add Skedulo/agent-skills@skedulo-cli` |

## Contributing

To add a new skill, create a directory under `skills/` with a `SKILL.md` file:

```
skills/
  my-new-skill/
    SKILL.md              # Required — main skill file with YAML frontmatter
    supporting-file.md    # Optional — heavy reference or supporting material
```

See the [Skills documentation](https://skills.sh/) for authoring guidelines.

## Resources

- [Skedulo Developer Documentation](https://docs.skedulo.com/)
- [Skedulo CLI Examples](https://github.com/skeduloDevelopers/SkeduloCLIExamples)
- [Skills CLI](https://skills.sh/)
