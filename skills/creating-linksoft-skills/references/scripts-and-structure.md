# Scripts and Structure

Use this reference when deciding how to structure a skill or whether to bundle scripts.

## Directory structure

Base structure:

```text
skills/<skill-name>/
|- SKILL.md
|- README.md
|- assets/
|- references/
|- scripts/
`- evals/
```

Only include directories that add value.

## Progressive disclosure

Organize the skill so the agent loads the smallest useful amount of information first and only pulls in more context on demand:

1. `name` and `description` are read for discovery
2. the `SKILL.md` body is loaded when the skill activates
3. `references/`, `scripts/`, and `assets/` are loaded only when needed

Keep `SKILL.md` focused on the core workflow the agent needs on most activations. Move deeper reference material out of it so the extra context is loaded only when the task calls for it.

Use references when:

- advanced cases are not needed every run
- you have long examples, schema details, or decision tables
- you need separate docs for distinct subtopics

Do not create deep chains such as `SKILL.md -> reference A -> reference B`. Link directly from `SKILL.md` whenever possible.

## When to add a script

Bundle a script when the task is:

- repetitive
- fragile
- easier to verify mechanically than by prose alone
- likely to be repeated across many runs

Prefer a one-off command when an existing tool already solves the task cleanly.

When reusable logic is worth bundling, prefer scripts that are as self-contained as practical. Declare runtime prerequisites clearly, and use inline dependency mechanisms or version-pinned runners when that makes execution more reliable.

## Script design rules

- Use relative paths from the skill root when referencing scripts
- Keep scripts non-interactive
- Accept input through flags, environment variables, or stdin instead of prompts
- Document usage with `--help`
- Keep `--help` concise enough for the agent to scan quickly
- Prefer structured stdout for data the agent will parse
- Send diagnostics and progress messages to stderr when practical
- Use clear errors that say what went wrong and how to fix it
- Pin tool versions for reproducibility when using one-off package runners such as `npx`, `uvx`, or similar tools
- Prefer safe defaults for destructive or stateful operations, such as `--dry-run` or explicit confirmation flags
- If output may be large, default to summaries or support file, offset, or limit patterns so the agent can request more detail safely

Examples:

```markdown
Run validation:
python3 scripts/validate.py --input data.json
```

```markdown
Run formatting with a pinned one-off tool:
npx prettier@3.4.2 --check README.md
```

## Validation assets

Use:

- `evals/evals.json` for structured output-quality evals
- harness scripts only when the skill has executable behavior worth isolating

For more guidance, follow:

- https://agentskills.io/skill-creation/using-scripts
- https://agentskills.io/specification
