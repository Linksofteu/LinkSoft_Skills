# AGENTS.md

Agent instructions for working in the LinkSoft Skills repository.

## Purpose

This repository hosts reusable AI agent skills under `skills/`.
Each skill should be self-contained, discoverable by `npx skills`, and documented clearly for maintainers and users.

## Repository Layout

- `skills/<skill-name>/SKILL.md` (required)
- `skills/<skill-name>/README.md` (recommended)
- `skills/<skill-name>/scripts/*` (optional helper scripts)
- `skills/<skill-name>/tests/*` (recommended scenarios/checks)
- `README.md` (repo usage and licensing overview)
- `CONTRIBUTING.md` (contributor workflow and standards)

## Skill Authoring Rules

When adding or updating a skill:

1. Keep skill names lowercase and hyphenated.
2. Ensure `SKILL.md` has valid YAML frontmatter with:
   - `name`
   - `description`
3. Prefer explicit, procedural instructions:
   - what the skill does
   - when to use it
   - step-by-step behavior
4. Keep scripts cross-platform where practical (Bash + PowerShell for CLI skills).
5. Add or update usage examples and edge-case scenarios in the skill folder.

Reference specification:

- https://agentskills.io/specification

## Validation Checklist

Before finalizing changes, run:

- `npx skills add . --list`
- `npx skills add . --skill <skill-name>`

If scripts changed, also run relevant syntax checks and behavior smoke tests (for example, `bash -n` for shell scripts, PowerShell parse checks for `.ps1`).

## Licensing and Attribution

Default license behavior:

- Repository default license is MIT.
- Skills use repository license unless a skill folder provides its own license.

Per-skill override:

- `skills/<skill-name>/LICENSE`
- `skills/<skill-name>/NOTICE` (when required, e.g., Apache-2.0 attribution)

For adapted or derived third-party skills, preserve required attribution and notices.

## Editing Guidance for Agents

- Make focused changes; avoid unrelated refactors.
- Preserve existing conventions in touched files.
- Update docs (`README.md`, skill `README.md`, tests/scenarios) when behavior changes.
- Bump `metadata.version` in `SKILL.md` for meaningful behavior changes.
- Do not remove existing licensing or attribution content.

## Pull Request Expectations

PRs should include:

- What changed
- Why it changed
- How it was validated (commands/tests)
- Any licensing or attribution impact
