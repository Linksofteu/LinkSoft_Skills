# creating-linksoft-skills

Create or improve Agent Skills that follow the Agent Skills format and LinkSoft repository conventions.

## Contents

- `SKILL.md`: agent-facing workflow for designing and revising skills
- `references/descriptions-and-evals.md`: guidance for trigger descriptions and output-quality evals
- `references/scripts-and-structure.md`: guidance for directory structure, progressive disclosure, and scripts
- `evals/evals.json`: starter eval cases for this skill

## What this skill covers

- scoping a skill to one coherent job
- choosing a spec-compliant name
- writing a strong trigger description
- keeping `SKILL.md` concise
- organizing `assets/`, `references/`, `scripts/`, and `evals/`
- checking repository compliance before finalizing

## Source guidance

This skill is aligned to:

- [Quickstart](https://agentskills.io/skill-creation/quickstart)
- [Best practices](https://agentskills.io/skill-creation/best-practices)
- [Optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
- [Evaluating skills](https://agentskills.io/skill-creation/evaluating-skills)
- [Using scripts](https://agentskills.io/skill-creation/using-scripts)
- [Specification](https://agentskills.io/specification)

## Repository expectations

Agent Skills format expectations:

- Keep `name` lowercase and hyphenated, matching the folder name
- Include valid YAML frontmatter with required `name` and `description`
- Add optional supporting directories such as `assets/`, `references/`, `scripts/`, and `evals/` only when they add value

LinkSoft repository expectations:

- Store skills under `skills/<skill-name>/`
- Include `metadata.author` and `metadata.version`
- Include `README.md` for every skill
- Add `evals/`, `scripts/`, or `references/` when they add value or repository guidance calls for them
- Bump `metadata.version` for meaningful behavior changes
- Use the repository MIT license unless the skill folder carries its own license files

## Validation notes

Before finalizing, validate that the skill is discoverable and installable:

```bash
npx skills add . --list
npx skills add . --skill creating-linksoft-skills
```

If scripts are added or changed, also run the relevant syntax or smoke checks for those scripts.
