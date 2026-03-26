---
name: creating-linksoft-skills
description: Create or improve Agent Skills that follow the Agent Skills specification and LinkSoft repository conventions. Use this skill when designing a new skill, tightening scope, writing descriptions, structuring references or scripts, adding evals, or reviewing an existing skill for clarity, discoverability, and reuse.
metadata:
  author: Softgraphy GK
  version: "1.2.0"
---

## Purpose

Use this skill to create or revise a reusable Agent Skill in the standard Agent Skills format that is:

- narrowly scoped
- easy for agents to trigger correctly
- concise in `SKILL.md`
- structured with progressive disclosure
- documented and validated using this repository's conventions

## Workflow

### 1. Confirm the job the skill should do

Start from real expertise before creating files.

- Start from a real task completed with an agent, or from project artifacts such as runbooks, internal docs, style guides, API specs, schemas, issue trackers, review comments, and prior fixes.
- Extract the steps that actually worked, the corrections that were needed, the repeatable procedure, the project-specific constraints and gotchas, and the expected inputs and outputs.
- After drafting the skill, try it on real tasks and fold recurring mistakes, missing steps, or incorrect assumptions back into the instructions.
- If the request is vague, narrow it until you can state one clear unit of work and its scope boundary.

Good scope checks:

- Can you say what is in scope and out of scope in 1-2 sentences?
- Would one agent usually use this skill for one coherent task?
- If the skill starts to cover unrelated workflows, split it.

### 2. Choose a compliant name

The skill name must match the folder name and the spec:

- lowercase letters, numbers, and hyphens only
- no leading or trailing hyphen
- no consecutive hyphens
- concise and specific

Prefer names that describe the capability, not generic helper terms.

Examples:

- Good: `opening-in-ide`, `reviewing-skills`, `creating-linksoft-skills`
- Avoid: `skill-helper`, `misc-tools`, `data-handler`

### 3. Write the description for triggering

The description is the main trigger signal. Write it in imperative form around user intent.

Use this pattern:

```yaml
description: Use this skill when ...
```

Description guidance:

- say what the skill helps accomplish
- say when it should be used
- include likely user intents and domain terms
- stay specific enough to avoid false positives
- keep it concise and well below the 1024-character limit
- prefer roughly 1 sentence and usually no more than about 200 characters unless a slightly longer description is clearly necessary for trigger accuracy
- move procedural detail, caveats, and examples into `SKILL.md` instead of the description

Good example:

```yaml
description: Use this skill when creating or improving Agent Skills, including naming, description writing, progressive disclosure, scripts, evals, and repository compliance.
```

Avoid descriptions like `Helps with skills.` or descriptions that only explain implementation details.

Treat description length as a real constraint because descriptions are loaded into context during activation.

If the user asks for description tuning, use the process in `references/descriptions-and-evals.md`.

### 4. Keep `SKILL.md` lean

Put only the instructions the agent needs on nearly every activation into `SKILL.md`.

Include:

- purpose and activation context
- the core workflow
- critical defaults
- links to references, scripts, templates, or eval assets

Use progressive disclosure to spend context wisely. Do not overload `SKILL.md` with long background explanations, exhaustive examples, or large reference material. Keep the main body under about 5,000 tokens, keep it under 500 lines, and prefer much shorter when possible.

If the skill needs detailed supporting material, move it to `references/` and tell the agent exactly when to read each file.

### 5. Structure the skill directory

Start from the Agent Skills format, then apply LinkSoft repository requirements.

Agent Skills format minimum:

```text
<skill-name>/
`- SKILL.md
```

LinkSoft repository layout for this repo:

```text
skills/<skill-name>/
|- SKILL.md
|- README.md
|- assets/
|- references/
|- scripts/
`- evals/
```

Treat these as building blocks, not a mandatory checklist. Add only the files and directories that materially improve the skill.

- `assets/`: reusable templates, schemas, and other static resources the agent can load on demand
- `README.md`: required by this repository for human-facing overview, contents, usage notes, and validation notes
- `references/`: add when detailed instructions are only needed in some runs
- `scripts/`: add when reusable executable helpers are more reliable than repeated prose instructions
- `evals/`: add when the skill benefits from machine-friendly evaluation, usually `evals/evals.json`

Avoid redundant docs like separate installation guides unless they add real value.

When creating a brand new skill, do not guess `metadata.author` if the correct value is unknown.

- If the user already provided the author or it is unambiguous from the conversation, use that value.
- If the correct author is not known and you need to create `metadata.author`, ask the user who the author should be before finalizing the files.
- Do not silently copy an author from another skill unless the user clearly wants that.

### 6. Add references with progressive disclosure

Use references only when they save context or isolate advanced material.

- Keep references one level away from `SKILL.md`
- Use descriptive filenames
- Tell the agent exactly when to read each reference, using explicit `read ... when ...` or `read ... if ...` instructions
- Avoid nested reference chains
- Avoid duplicating the same instruction in multiple files

Examples:

- Read `references/descriptions-and-evals.md` when improving trigger accuracy or adding eval queries.
- Read `references/scripts-and-structure.md` when deciding whether to bundle scripts or how to document them.

### 7. Bundle scripts only when they add value

Use a bundled script when the agent would otherwise repeat fragile or mechanical logic across runs.

For scripts:

- reference them with relative paths from the skill root
- keep them as self-contained as practical, using inline dependencies or version-pinned one-off runners when that makes execution more reliable
- keep them non-interactive and accept input through flags, environment variables, or stdin instead of prompts
- document usage with concise `--help`
- emit structured output to stdout when practical
- send diagnostics and progress messages to stderr when useful
- use clear errors that say what went wrong and how to fix it
- prefer idempotent behavior when retries are likely
- add `--dry-run` or explicit confirmation flags such as `--confirm` or `--force` for destructive or stateful actions when appropriate
- use meaningful exit codes when they help the agent recover or choose the next step
- state runtime prerequisites clearly

If a one-off command is enough, prefer that over adding a script. Read `references/scripts-and-structure.md` when deciding.

### 8. Add evals early

Use `evals/evals.json` for output-quality evaluation. Start with 2-3 realistic prompts and grow from there.

When evaluation grows beyond a quick spot check, organize runs by iteration and keep outputs separated for the current skill and the baseline. Save grading, timing, or benchmark artifacts when that structure helps you compare results over time.

Each eval can include:

- `prompt`
- `expected_output`
- `files`
- `assertions`

Use realistic prompts with file paths, concrete details, and near-miss cases where relevant. Compare the skill against a baseline where possible, such as no skill, a previous version of the skill, or another reasonable point of comparison.

After running evals, review failures and patterns, not just pass rates. Use recurring issues to tighten instructions, defaults, or gotchas, and include human review when quality depends on judgment that assertions do not capture well.

If the user wants trigger optimization, create should-trigger and should-not-trigger queries as described in `references/descriptions-and-evals.md`.

### 9. Check compliance before finishing

Before finalizing, check both the Agent Skills format and LinkSoft repository requirements.

Agent Skills format requirements:

- the skill has valid frontmatter with required `name` and `description`
- optional fields such as `license`, `compatibility`, `metadata`, and `allowed-tools` are used only when they add value
- the folder name matches the `name` field and follows naming rules
- file references and supporting materials follow `agentskills.io` guidance

LinkSoft repository requirements:

- the skill lives under `skills/<skill-name>/`
- `SKILL.md` includes `metadata.author` and `metadata.version`
- when creating a new skill, ask for `metadata.author` if it is not already known
- `README.md` is present
- `metadata.version` is updated for meaningful behavior changes
- `evals/evals.json` is added or updated when behavior warrants evaluation
- the skill uses the repository default MIT license unless the skill folder includes its own `LICENSE` and any required `NOTICE`

## Defaults and patterns

- Prefer procedures over generic advice.
- Provide a default approach instead of long menus of options.
- Include gotchas when the agent would likely make a wrong assumption.
- Use templates for structured outputs.
- Add validation loops only when they materially improve reliability.
- Mention `allowed-tools` only if it is genuinely needed; it is optional and experimental, so do not add it by default.

## References

- `references/descriptions-and-evals.md`: description writing, trigger evals, output-quality evals
- `references/scripts-and-structure.md`: progressive disclosure, scripts, directory structure
