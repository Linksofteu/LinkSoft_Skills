# Migration playbook

Read this reference when changing packages, ABP module registration, call sites, or validation.

## 1. Inventory and boundary

Find all of the following before removing anything:

- `AutoMapper`, `Volo.Abp.AutoMapper`, `Profile`, and `CreateMap`
- `AbpAutoMapperModule`, `AddAutoMapperObjectMapper`, and `AbpAutoMapperOptions`
- direct `IMapper` injection, `ProjectTo`, `MapFrom`, `ForMember`, `ForPath`, `IncludeMembers`, `IncludeBase`, `ReverseMap`, converters, resolvers, conditions, hooks, and context items
- ABP helpers such as `MapExtraProperties`, audit-property ignores, and mapping tests
- projects sharing profiles or depending on a module that owns the mapper registration

Run the bundled inventory script as a starting point, not as proof of completeness:

```bash
.agents/skills/abp-automapper-to-mapperly/scripts/inventory-automapper.sh --root .
```

Keep the ABP version upgrade separate from mapping conversion in the reasoning and diff. Use the target repository's existing version-management style (`Directory.Packages.props`, project files, lock files, or another mechanism); never paste a version from an example migration.

## 2. Packages and module registration

For each mapper-owning project, replace the ABP AutoMapper integration with the matching Mapperly integration version:

```xml
<PackageReference Include="Volo.Abp.Mapperly" Version="$(AbpVersion)" />
```

Adapt centralized package management rather than duplicating a `Version` attribute when the repository centralizes versions.

In the ABP module:

```csharp
using Volo.Abp.Mapperly;

[DependsOn(typeof(AbpMapperlyModule))]
public class SalesApplicationModule : AbpModule
{
    public override void ConfigureServices(ServiceConfigurationContext context)
    {
        context.Services.AddMapperlyObjectMapper<SalesApplicationModule>();
    }
}
```

Remove the corresponding AutoMapper registration:

```csharp
context.Services.AddAutoMapperObjectMapper<SalesApplicationModule>();
Configure<AbpAutoMapperOptions>(options =>
    options.AddMaps<SalesApplicationModule>(validate: true));
```

Verify whether `AbpMapperlyModule` is already inherited through a depended-on module. Prefer an explicit dependency in a reusable module when that makes the module independently valid; do not add duplicates mechanically.

## 3. Convert profiles by behavior

Use this translation guide, then inspect the detailed examples in `mapping-patterns.md`.

| AutoMapper construct | Typical Mapperly/ABP replacement |
|---|---|
| `CreateMap<S, T>()` | `[Mapper]` class deriving `MapperBase<S, T>` |
| `.ReverseMap()` | `TwoWayMapperBase<S, T>` or two directional mappers |
| `.ForMember(...MapFrom(...))` | `[MapProperty]`, `[MapPropertyFromSource]`, or a named user method |
| `.Ignore(...)` | `[MapperIgnoreTarget]` on both create and update methods |
| `.IncludeMembers(...)` / flattening | `[MapNestedProperties]` and explicit property paths |
| constant assignment | `[MapValue]` |
| `.MapExtraProperties()` | `[MapExtraProperties]` |
| `.AfterMap(...)` | preferably an explicit user mapping for deterministic transformations; otherwise a top-level ABP `AfterMap` or explicit orchestration |
| converter/resolver | named user mapping selected with `Use`, or a hand-written mapper/orchestration when contextual |
| nested type already has a Mapperly mapper | inject it and annotate the initialized field/property with `[UseMapper]` |
| `.ConstructUsing(...)` | Mapperly object factory if supported by the selected version |
| `.ProjectTo<T>()` | rewrite explicitly; do not assume object mapping translates to SQL |

Use `nameof` for Mapperly member names, method names, ignored members, constants, and mapping references whenever the attribute API permits it. Avoid raw strings because they do not follow refactors. Use a string only when the installed API requires one and no valid `nameof` representation exists; keep that exception narrow and explain it.

Ordinary C# `nameof(Customer.Account.Id)` evaluates to only `"Id"`, not `"Account.Id"`. For nested paths, preserve each segment with an array:

```csharp
[MapProperty(
    [nameof(Customer.Account), nameof(Customer.Account.Id)],
    nameof(CustomerDto.AccountId))]
```

Current Mapperly versions may also support full-`nameof` syntax such as `nameof(@Customer.Account.Id)`. Use it only after verifying support in the target version; the segment-array form is explicit and works with versions that accept path arrays. Apply the same rule to nested target paths. Keep mapping attributes adjacent to the method they configure. If attributes apply separately to create and update methods, duplicate them intentionally or use a verified configuration-reuse feature; never assume configuration automatically flows between overloads.

Mapperly automatically discovers user-implemented mapping methods by default. Discovery is based on compatible source and target types, not on a helper's name or visibility. A narrowly intended helper such as `bool ToActive(bool)` can therefore affect unrelated `bool` properties in the same mapper. When selecting a helper through `Use`, mark it `[UserMapping(Default = false)]`. For tighter control, configure `[Mapper(AutoUserMappings = false)]`, use `Use` for property-specific helpers, and mark other intended user mappings explicitly. Review every helper by its type signature during migration, especially same-type methods such as `bool -> bool` and `string -> string`.

Before recreating a nested mapping, search for an existing Mapperly mapper with the same source/target pair. Prefer composing it through `[UseMapper]`; see `mapping-patterns.md`. Verify that ABP registers the reused mapper and can satisfy its constructor dependencies. Mapperly does not instantiate `[UseMapper]` members, so the containing mapper must initialize them, normally through constructor injection. If multiple external mappers expose compatible methods, resolve the ambiguity explicitly rather than depending on discovery order. `AutoUserMappings = false` also affects discovery of external mapper methods; do not combine it with implicit `[UseMapper]` reuse without confirming the installed Mapperly version and selecting the intended method explicitly where supported.

Do not put required reusable behavior only in `BeforeMap` or `AfterMap`. Those are ABP lifecycle hooks around direct mapper invocation; a parent Mapperly mapper consuming the mapping through `[UseMapper]` calls the mapping method without running the reused mapper's ABP hooks. Prefer explicit user mappings and `[UseMapper]` composition for deterministic behavior. Keep `AfterMap` for top-level-only synchronous enrichment, or move contextual/service-driven enrichment into explicit orchestration.

When using `IncludeMappingConfiguration`, audit every included `Use = nameof(...)` reference. The mapping attributes are reused, but the referenced helper implementation must also be available to the consuming mapper. Mapperly also requires the included source and target types to be the same as or base types of the consuming mapping's types. For closely related create/update inputs that derive from a shared change DTO and target one model, prefer a single `[Mapper]` class that derives from `MapperBase<TCreate, TModel>` and implements `IAbpMapperlyMapper<TUpdate, TModel>` so both mapping pairs and their helpers remain in the same scope. For unrelated input types, repeat the attributes on each mapping while sharing the helper method.

## 4. Call sites

ABP code using `IObjectMapper` or `IObjectMapper<TContext>` usually remains unchanged after module registration. Preserve contextual mappers in reusable modules so the host's default mapper cannot change their behavior.

Rewrite direct AutoMapper dependencies:

- replace `IMapper` injection with the appropriate ABP object mapper or a dedicated mapper
- replace `ProjectTo` with an explicit server-side projection or another query strategy; validate SQL translation and selected columns
- replace mapping context items and service locators with explicit inputs or a hand-written mapper
- avoid synchronous blocking on async services inside mapping hooks

Generated mapping should stay deterministic and side-effect free. If a result depends on current user, authorization, database state, localization, or external services, keep that orchestration explicit. A custom `IObjectMapper<TSource,TTarget>` may be the clearest ABP integration point.

## 5. Tests and validation

Before changing tests, ask the user: **Do you want behavior tests created for the migrated mappings?** Do not infer the answer from the migration request.

If the user says yes, preserve existing behavior tests and add focused tests covering applicable behavior such as:

- create-new and update-existing overloads
- renamed and flattened fields
- ignored/enriched fields
- null and default-value behavior
- collection replacement or merge behavior
- extra properties and audit properties where applicable
- reverse and polymorphic mappings

If the user says no:

- do not create replacement behavior tests
- remove only tests whose sole purpose is validating AutoMapper profiles or configuration, such as tests that only construct an AutoMapper configuration or call `AssertConfigurationIsValid()`
- preserve tests that exercise mapped values, defaults, hooks, update-existing behavior, collections, or application behavior, even if their class or filename mentions AutoMapper or `Profile`
- if a test mixes AutoMapper configuration validation with behavioral assertions, remove only the obsolete configuration-specific portion and retain the behavioral coverage

With authorization to build/test, validate the smallest affected projects first and then the broader solution. Treat generator warnings and errors as correctness signals. Inspect generated code when behavior is surprising.

Finish with searches for stale integration and APIs:

```bash
rg -n --glob '*.cs' --glob '*.csproj' --glob 'Directory.Packages.props' \
  'Volo\.Abp\.AutoMapper|AbpAutoMapper|AddAutoMapperObjectMapper|AutoMapper|\bProfile\b|\bIMapper\b|ProjectTo'
```

Some AutoMapper references may be intentionally out of scope or third-party requirements. Document them rather than deleting them blindly. Update lock files using the repository's normal restore workflow.
