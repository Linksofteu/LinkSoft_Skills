---
name: abp-automapper-to-mapperly
description: Use this skill when migrating an ABP Framework application or module from AutoMapper profiles to ABP's Mapperly integration, including registration, mappings, call sites, and tests.
metadata:
  author: Martin Koudelka
  version: "1.0.6"
---

# Migrate ABP AutoMapper to Mapperly

Convert an ABP module from runtime AutoMapper profiles to explicit, source-generated Mapperly mappings while preserving mapping behavior and ABP's `IObjectMapper` abstraction.

This skill covers the mapping-library migration, whether performed alone or as part of an ABP upgrade. Do not copy unrelated framework-upgrade changes, database migrations, package versions, or application-specific conventions from an example project.

## Workflow

1. Read the repository instructions and determine the requested scope: one mapping pair, one module, or the solution. Do not add packages, build, or make unrelated upgrade changes when local instructions require separate approval.
2. Inventory AutoMapper packages, module registration, profiles, direct `IMapper` usage, projections, custom resolvers/converters, hooks, inheritance, and tests. Run `scripts/inventory-automapper.sh --root <repository>` for an initial read-only scan, then inspect every reported mapping semantically.
3. Establish behavior before editing. Record renamed, flattened, ignored, defaulted, computed, enriched, reverse, collection, nullable, extra-property, and update-existing-target behavior. Ask the user whether they want behavior tests created for the migrated mappings. If yes, add focused behavior tests. If no, do not create replacement tests and remove only tests whose sole purpose is AutoMapper profile/configuration validation. Preserve all existing behavior tests in either case.
4. Read [references/migration-playbook.md](references/migration-playbook.md) for package, module, call-site, and validation changes. Consult the current ABP and Mapperly documentation for the versions actually used by the target repository before relying on version-sensitive attributes or generator behavior.
5. Convert profiles in small coherent groups. Read [references/mapping-patterns.md](references/mapping-patterns.md) and choose the narrowest fitting pattern. Prefer composable `[UserMapping(Default = false)]` methods selected with `Use = nameof(...)`, and reuse authoritative nested mappers with constructor injection and `[UseMapper]`. Reserve `AfterMap` for behavior that belongs only to a directly invoked, top-level ABP mapper.
6. Treat Mapperly compiler diagnostics as migration feedback. Default to `RequiredMappingStrategy.Target`; fix or explicitly ignore each target member. Do not broadly disable diagnostics to make the migration compile.
7. Validate each converted group in proportion to risk, following repository approval rules. Check generated-code diagnostics, mapping behavior, update mappings, null cases, and remaining AutoMapper references before removing the old package or profile.

## Required outcomes

- The owning ABP module uses `Volo.Abp.Mapperly`, depends on `AbpMapperlyModule` directly or through a verified dependency, and calls `AddMapperlyObjectMapper<TModule>()`.
- Each ordinary pair is implemented with `MapperBase<TSource, TTarget>` and declares both `Map(source)` and `Map(source, destination)` unless the target ABP version's base class supplies a verified equivalent.
- Symmetric reverse mappings use `TwoWayMapperBase<TLeft, TRight>` only when both directions truly share semantics; otherwise create separate directional mappers.
- `IObjectMapper` call sites remain library-agnostic where possible. Direct AutoMapper APIs such as `IMapper`, `ProjectTo`, profiles, resolvers, and mapping context items are replaced deliberately.
- Fields populated later by orchestration are explicitly ignored, while fields owned by mapping are mapped or computed. An ignore must not silently erase behavior formerly implemented by `ForMember`, `AfterMap`, a resolver, or a converter.
- Mapper attributes use `nameof` for member and method references whenever the installed API permits it. Nested paths preserve every segment with a `nameof` segment array or Mapperly's version-supported full-`nameof` syntax; never use plain `nameof(Type.Parent.Child)` as though it produced a full path.
- Narrow helper methods selected with `MapProperty(..., Use = ...)` are not allowed to become implicit converters for every matching type pair. With Mapperly's default automatic discovery, mark them `[UserMapping(Default = false)]`; alternatively disable `AutoUserMappings` for the mapper and opt methods in explicitly.
- Existing Mapperly mappers for nested source/target pairs are composed with `[UseMapper]` where supported. The containing mapper initializes the referenced instance, and ambiguity between multiple compatible external mappings is resolved deliberately.
- Required reusable mapping behavior is implemented in Mapperly mapping methods or explicit user mappings, not only in ABP `BeforeMap`/`AfterMap` hooks. When another mapper consumes a mapper through `[UseMapper]`, Mapperly calls the exposed mapping method and does not run that mapper's ABP lifecycle hooks; behavior placed only in `AfterMap` would therefore be lost.
- An included mapping configuration does not make referenced helper/user-mapping implementations magically available in the consuming mapper. Every method named by `Use` in the included configuration must also be discoverable from that mapper, and the included source and target types must be assignable from the consuming mapping's types. For related inputs that derive from a shared base DTO, prefer co-locating the mappings in one `[Mapper]` class—deriving from `MapperBase<TPrimarySource, TTarget>` for the primary pair and implementing `IAbpMapperlyMapper<TSecondarySource, TTarget>` for the additional pair—so configuration and helpers share one scope. Otherwise, repeat the mapping attributes while sharing the helper implementation.
- Existing-target mappings preserve identity and collection semantics. Verify them separately from create-new mappings.
- The user explicitly chooses whether new behavior tests are created. Declining them authorizes removal only of AutoMapper-specific configuration tests, never unrelated or existing behavior tests.
- AutoMapper is removed only after a solution-wide scan confirms that no in-scope module or transitive integration still requires it.

## Escalate instead of guessing

Stop and report the unresolved behavior when a mapping depends on runtime context, asynchronous I/O, authorization, ambient services, expression-tree projection, reference preservation, polymorphism, or collection merge semantics that cannot be represented faithfully by the selected Mapperly/ABP version. Prefer a hand-written `IObjectMapper<TSource,TTarget>` for orchestration-heavy behavior rather than hiding it in generated mapping attributes.
