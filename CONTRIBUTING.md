<!-- omit in toc -->
# Contribution Guide

LinkSoft Skills is an open source repository of reusable AI agent skills.

This repository is primarily licensed under MIT. See [Licensing and Attribution](#licensing-and-attribution) for per-skill license overrides (for example, Apache-2.0 derived skills).

<!-- omit in toc -->
## Table of Contents

- [I Have a Question](#i-have-a-question)
- [Contributing Skills](#contributing-skills)
  - [Before You Start](#before-you-start)
  - [Skill Structure](#skill-structure)
  - [Skill Quality Checklist](#skill-quality-checklist)
  - [Validation Before PR](#validation-before-pr)
- [Licensing and Attribution](#licensing-and-attribution)
- [Bug Reports and Enhancements](#bug-reports-and-enhancements)
  - [Submitting a Bug Report](#submitting-a-bug-report)
  - [Suggesting Enhancements](#suggesting-enhancements)
- [Code of Conduct](#code-of-conduct)
- [Attribution](#attribution)

## I Have a Question

Before opening a question, please check:

- Existing repository issues
- The skills CLI docs at `https://skills.sh/docs` and `https://github.com/vercel-labs/skills`
- Existing skills in this repository for examples

If your question is still unanswered, open an issue in this repository and include:

- What you are trying to do
- What you expected to happen
- What happened instead
- Relevant environment details (OS, shell, Node/npm/npx versions, agent used)

## Contributing Skills

<!-- omit in toc -->
### Legal Notice

By contributing, you confirm that:

- You have the rights to contribute the content
- Your contribution can be distributed under this repository's licensing model
- Any third-party derived content includes proper attribution and license compliance

### Before You Start

Please open an issue first for major changes (new skill proposals, substantial rewrites, or behavioral changes), so we can align on scope and naming before implementation.

For minor fixes (typos, metadata corrections, small clarity improvements), you may open a PR directly.

### Skill Structure

Add each new skill under:

- `skills/<skill-name>/SKILL.md`

Recommended additional files:

- `skills/<skill-name>/README.md`
- `skills/<skill-name>/scripts/*`
- `skills/<skill-name>/tests/*`

`SKILL.md` must include YAML frontmatter with at least:

- `name` (lowercase, hyphenated)
- `description` (clear trigger/use-case)

See the [Agent Skills specification](https://agentskills.io/specification) for more detail.

### Skill Quality Checklist

A good skill should:

- Have a clear, specific purpose
- Explain when the skill should be used
- Provide actionable, step-by-step behavior
- Avoid ambiguous or contradictory instructions
- Match repository conventions for naming and structure

### Validation Before PR

Please validate your contribution locally:

- `npx skills add . --list` to confirm discovery
- `npx skills add . --skill <skill-name>` to verify installability
- If relevant, test helper scripts on supported platforms

Also ensure:

- Paths and command examples in docs are correct
- Frontmatter is valid YAML
- No secrets or credentials are committed

## Licensing and Attribution

Default rule:

- This repository is licensed under MIT
- All skills use the repository license unless a skill folder explicitly includes another license

Per-skill override:

- Add `skills/<skill-name>/LICENSE`
- Add `skills/<skill-name>/NOTICE` when required (for example, Apache-2.0 attribution flows)

If a skill is derived or adapted from third-party work, your PR must include:

- Source repository link
- Original author/organization credit
- Applicable license text and required notices in the skill folder

## Bug Reports and Enhancements

### Submitting a Bug Report

Open an issue in this repository with:

- Clear title
- Reproduction steps
- Expected vs actual behavior
- Affected skill path (for example, `skills/opening-in-rider`)
- Logs/error messages where relevant

Helpful environment details include:

- OS/platform and shell
- Node/npm/npx versions
- Agent target (for example, Codex, OpenCode, Claude Code)

### Suggesting Enhancements

Open an issue with:

- The problem you are solving
- Proposed behavior and usage trigger
- Why this should be a reusable skill (not one-off logic)
- Examples of expected outcomes

For new skills, include a proposed name and a short draft description.

## Code of Conduct

This project and everyone participating in it is governed by the
[LinkSoft Code of Conduct](https://github.com/Linksofteu/.github/blob/main/CODE_OF_CONDUCT.md).

Please report unacceptable behavior to <opensource@linksoft.cz>.

## Attribution

This guide was adapted from internal LinkSoft contribution guidance and community open-source templates.
