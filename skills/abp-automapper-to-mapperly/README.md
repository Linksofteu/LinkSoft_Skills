# ABP AutoMapper to Mapperly

Reusable Agent Skill for migrating ABP Framework modules from AutoMapper profiles to ABP's Mapperly integration.

It covers:

- package and ABP module registration changes
- behavior-based translation of profiles to `MapperBase` or `TwoWayMapperBase`
- renamed, flattened, ignored, computed, constant, enriched, reverse, extra-property, and collection mappings
- refactor-safe `nameof` references, nested path arrays, and `MapPropertyFromSource`
- composable user mappings and reuse of existing nested mappers with `UseMapper`, with explicit warnings about `AfterMap` lifecycle boundaries
- safe `IncludeMappingConfiguration` usage, including helper-method scope and combined `MapperBase`/`IAbpMapperlyMapper` classes
- direct AutoMapper call sites and projection caveats
- diagnostics, a user choice about creating behavior tests, and safe removal checks

The mapping examples are generalized from a large production migration. They intentionally use neutral domain types and do not encode the source project's namespaces, versions, or business rules.

## Usage

Invoke the skill with a scoped request, for example:

```text
Use $abp-automapper-to-mapperly to migrate the Sales application module from AutoMapper to Mapperly while preserving its mapping tests.
```

The bundled inventory helper is read-only:

```bash
.agents/skills/abp-automapper-to-mapperly/scripts/inventory-automapper.sh --root .
```

## Contents

- `SKILL.md` — core migration workflow and completion criteria
- `references/migration-playbook.md` — packages, module registration, call sites, and validation
- `references/mapping-patterns.md` — generic conversion examples and advanced-case guidance
- `scripts/inventory-automapper.sh` — repository scan for migration-sensitive AutoMapper usage
- `evals/evals.json` — realistic output-quality evaluation cases

## Validation

Validate the skill structure with the bundled Codex skill validator and run the inventory helper against a representative ABP repository. Migration results still require compilation under the target repository's own build and approval rules; new behavior tests are created only when the user opts in.
