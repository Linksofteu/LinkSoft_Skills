# LinkSoft_Skills
Public repository for AI agentic skills.

See `CONTRIBUTING.md` for contribution guidelines.

## Adding a New Skill

1. Create a new folder under `skills/`:

   - `skills/<skill-name>/`

2. Add a `SKILL.md` file with YAML frontmatter:

   - Required fields: `name`, `description`
   - Recommended naming: lowercase with hyphens (for example, `my-new-skill`)

3. Write clear instructions in `SKILL.md`:

   - What the skill does
   - When to use it
   - Step-by-step behavior the agent should follow

4. Add supporting assets as needed:

   - `scripts/` for helper scripts
   - `README.md` for usage notes
   - `tests/` for scenarios/examples

5. Set licensing for the skill:

   - No additional files needed if it uses the repository default MIT license
   - Add `LICENSE` (and `NOTICE` when required) in the skill folder for license overrides

6. Validate locally before publishing:

   - `npx skills add . --list` to confirm the skill is discoverable
   - `npx skills add . --skill <skill-name>` to verify install flow

## Licensing

This repository is licensed under the MIT License.

All skills are licensed under the repository license unless a skill folder explicitly includes a different license.

If a skill includes its own `LICENSE` (and where applicable `NOTICE`), that license governs that skill's contents.

To override the default license for a specific skill, add these files in that skill folder:

- `skills/<skill-name>/LICENSE`
- `skills/<skill-name>/NOTICE` (when required, such as Apache-2.0 attribution)
