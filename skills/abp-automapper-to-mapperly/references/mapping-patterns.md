# Mapping patterns

Read this reference while translating AutoMapper profiles. The examples are intentionally generic and show patterns rather than a project-specific naming scheme.

The snippets assume:

```csharp
using Riok.Mapperly.Abstractions;
using Volo.Abp.Mapperly;
```

Confirm attribute names and signatures against the installed ABP and Mapperly versions.

Use `nameof` instead of string literals for members and mapping methods whenever possible. For nested paths, use a path-segment array (shown below) or Mapperly's full-`nameof` syntax only when the installed version supports it. Plain `nameof(Type.Parent.Child)` returns only the final member name and is not a complete path.

## Strict basic mapper

Start strict so every target member is accounted for:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class ProductToProductDtoMapper
    : MapperBase<Product, ProductDto>
{
    public override partial ProductDto Map(Product source);
    public override partial void Map(Product source, ProductDto destination);
}
```

Declare both methods because ABP's object mapper supports creating a target and updating an existing target.

## Rename, flatten, compute, and default

This replaces common `ForMember`, `IncludeMembers`, and `Ignore` chains:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class CustomerToCustomerDtoMapper
    : MapperBase<Customer, CustomerDto>
{
    [MapNestedProperties(nameof(Customer.Account))]
    [MapProperty(
        [nameof(Customer.Account), nameof(Customer.Account.Id)],
        nameof(CustomerDto.AccountId))]
    [MapProperty(
        [nameof(Customer.Account), nameof(Customer.Account.RequiredApprovals)],
        nameof(CustomerDto.RequiredApprovals), Use = nameof(MapRequiredApprovals))]
    [MapPropertyFromSource(
        nameof(CustomerDto.DisplayStatus), Use = nameof(MapDisplayStatus))]
    public override partial CustomerDto Map(Customer source);

    [MapNestedProperties(nameof(Customer.Account))]
    [MapProperty(
        [nameof(Customer.Account), nameof(Customer.Account.Id)],
        nameof(CustomerDto.AccountId))]
    [MapProperty(
        [nameof(Customer.Account), nameof(Customer.Account.RequiredApprovals)],
        nameof(CustomerDto.RequiredApprovals), Use = nameof(MapRequiredApprovals))]
    [MapPropertyFromSource(
        nameof(CustomerDto.DisplayStatus), Use = nameof(MapDisplayStatus))]
    public override partial void Map(Customer source, CustomerDto destination);

    [UserMapping(Default = false)]
    private static int MapRequiredApprovals(int? value) => value ?? 1;

    [UserMapping(Default = false)]
    private static string MapDisplayStatus(Customer source) =>
        source.IsActive ? "Active" : "Inactive";
}
```

An ignored member is a promise that another layer owns it. If this mapper owns the value, compute it explicitly instead of ignoring it.

## Named conversion and `MapPropertyFromSource`

Use `MapProperty` with `Use` when a target member is computed from one source member. Use `MapPropertyFromSource` when the target value needs the entire source object, commonly because it combines multiple source members:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class UserToExternalUserMapper
    : MapperBase<User, ExternalUser>
{
    [MapProperty(nameof(User.IsDeleted), nameof(ExternalUser.Active),
        Use = nameof(ToActive))]
    [MapPropertyFromSource(nameof(ExternalUser.DisplayName),
        Use = nameof(ToDisplayName))]
    public override partial ExternalUser Map(User source);

    [MapProperty(nameof(User.IsDeleted), nameof(ExternalUser.Active),
        Use = nameof(ToActive))]
    [MapPropertyFromSource(nameof(ExternalUser.DisplayName),
        Use = nameof(ToDisplayName))]
    public override partial void Map(User source, ExternalUser destination);

    [UserMapping(Default = false)]
    private static bool ToActive(bool isDeleted) => !isDeleted;

    [UserMapping(Default = false)]
    private static string ToDisplayName(User source) =>
        $"{source.GivenName} {source.FamilyName}".Trim();
}
```

Prefer source-member conversion for a single input. Use whole-source computation only when the target value genuinely depends on multiple source members.

The `MapPropertyFromSource` declaration above passes the complete `User` instance to `ToDisplayName` and assigns the returned string to `ExternalUser.DisplayName`. The target member and helper method are referenced with `nameof`; no source path is supplied because the source is the whole object.

### Prevent helper leakage

Mapperly automatically discovers compatible user methods unless `AutoUserMappings` is disabled. Method names and `private` visibility do not scope them to the property that names them in `Use`. Without `[UserMapping(Default = false)]`, `ToActive(bool) -> bool` may become the mapper's default `bool -> bool` conversion and invert unrelated Boolean properties.

Use one of these consistent strategies:

1. Keep the default `AutoUserMappings = true`, add `[UserMapping(Default = false)]` to every property-specific helper, and select it with `Use = nameof(...)`.
2. Set `[Mapper(AutoUserMappings = false, RequiredMappingStrategy = RequiredMappingStrategy.Target)]`; select property-specific helpers with `Use`, and explicitly annotate any other user mapping that should participate in automatic mapping.

Do not rely on a distinctive method name to constrain selection. Review same-type helpers (`bool -> bool`, `string -> string`, enum-to-same-enum) first because their unintended reach is easy to miss.

## Constants and ABP extra properties

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
[MapExtraProperties]
public partial class DocumentToListItemMapper
    : MapperBase<Document, ListItemDto>
{
    [MapValue(nameof(ListItemDto.IsFolder), false)]
    public override partial ListItemDto Map(Document source);

    [MapValue(nameof(ListItemDto.IsFolder), false)]
    public override partial void Map(Document source, ListItemDto destination);
}
```

Use ABP's audit-property ignore attributes when appropriate for the installed version. Do not map `ExtraProperties` as a normal dictionary when `[MapExtraProperties]` is intended to preserve ABP object-extension semantics.

## Reverse mappings

Use a two-way base only for genuinely symmetric mappings:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class TagToTagDtoMapper : TwoWayMapperBase<Tag, TagDto>
{
    public override partial TagDto Map(Tag source);
    public override partial void Map(Tag source, TagDto destination);
    public override partial Tag ReverseMap(TagDto destination);
    public override partial void ReverseMap(TagDto destination, Tag source);
}
```

If create/update DTOs have different ignored fields, defaults, validation, or ownership rules, use separate directional `MapperBase` classes instead.

## Prefer user mappings and `UseMapper` over `AfterMap`

Put deterministic mapping behavior in generated mapping methods or narrowly selected user mappings. This keeps it available when a parent mapper composes the mapper through `[UseMapper]`.

`BeforeMap` and `AfterMap` are ABP mapper lifecycle hooks. They run when the ABP mapper itself is invoked, but Mapperly's `[UseMapper]` composition calls the exposed generated mapping method; it does not run the reused mapper's ABP lifecycle hooks. A nested mapper whose required behavior exists only in `AfterMap` is therefore unsafe to reuse: direct mapping and parent mapping produce different results.

For pure transformations, prefer:

- `[MapProperty(..., Use = nameof(...))]` for one source member
- `[MapPropertyFromSource(..., Use = nameof(...))]` for the complete source object
- `[UserMapping(Default = false)]` on property-specific helper methods
- a separate authoritative mapper consumed through `[UseMapper]` for nested source/target pairs

Reserve `AfterMap` for synchronous enrichment owned by a directly invoked, top-level ABP mapper and not expected to participate in mapper composition. Make that limitation visible at the mapper and call sites.

### Top-level enrichment with an injected service

ABP mapper bases provide hooks that can use injected services, but keep mapping synchronous and avoid hidden I/O:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class OrderToOrderDtoMapper
    : MapperBase<Order, OrderDto>
{
    private readonly IStatusFormatter _statusFormatter;

    public OrderToOrderDtoMapper(IStatusFormatter statusFormatter)
    {
        _statusFormatter = statusFormatter;
    }

    [MapperIgnoreTarget(nameof(OrderDto.StatusText))]
    public override partial OrderDto Map(Order source);

    [MapperIgnoreTarget(nameof(OrderDto.StatusText))]
    public override partial void Map(Order source, OrderDto destination);

    public override void AfterMap(Order source, OrderDto destination)
    {
        destination.StatusText = _statusFormatter.Format(source.Status);
    }
}
```

Do not reuse the mapper above through `[UseMapper]` while expecting `StatusText` to be populated: its `AfterMap` hook will not run in that composition path. If formatting is a pure synchronous conversion, express it as a user mapping. If it is service-driven orchestration, perform it in the top-level caller or keep this mapper top-level-only.

When enrichment requires async calls, authorization decisions, database access, or ambient request state, perform it in the application/domain service or implement an explicit hand-written `IObjectMapper<TSource,TTarget>` whose behavior is visible and testable.

## Reusing mapping configuration

Large profiles often used extension methods or included base mappings. Prefer composition through well-named source/target types. If the installed ABP integration exposes `IncludeMappingConfiguration`, it can reuse verified method-level configuration:

```csharp
[IncludeMappingConfiguration(
    nameof(@CustomerInputToCustomerModelMapper.MapCommon))]
public override partial CustomerModel Map(CustomerCreateDto source);
```

The `@` opts into Mapperly's full-`nameof` interpretation while retaining compiler-checked symbols. Confirm that the installed Mapperly version supports it. Use a fully qualified string only as a version/API fallback, since string-based coupling is refactor-sensitive. Confirm the generated result, cover it with behavior tests when the user opted to create them, and prefer explicit attributes when reuse would obscure ownership.

**Warning:** `IncludeMappingConfiguration` reuses mapping configuration such as `MapProperty`; it does not copy the implementation of a helper referenced by `Use`. Every referenced mapping method must also be present or otherwise discoverable in the consuming mapper class. The included source and target types must also be the same as or base types of the consuming mapping's types. A configuration that contains `Use = nameof(NormalizeCode)` will fail when included in a mapper that cannot resolve `NormalizeCode`.

When create and update DTOs derive from a shared change DTO, the simplest design is often one mapper class. Use `MapperBase` for the primary pair and implement `IAbpMapperlyMapper` for the additional pair; then the mappings, included base configuration, and helpers share one scope:

```csharp
public abstract class CustomerChangeDto
{
    public string Code { get; set; } = string.Empty;
}

public sealed class CustomerCreateDto : CustomerChangeDto
{
}

public sealed class CustomerUpdateDto : CustomerChangeDto
{
}

[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class CustomerInputToCustomerModelMapper
    : MapperBase<CustomerCreateDto, CustomerModel>,
      IAbpMapperlyMapper<CustomerUpdateDto, CustomerModel>
{
    [MapProperty(
        nameof(CustomerChangeDto.Code),
        nameof(CustomerModel.Code),
        Use = nameof(NormalizeCode))]
    private partial void MapCommon(
        CustomerChangeDto source,
        CustomerModel destination);

    [IncludeMappingConfiguration(nameof(MapCommon))]
    public override partial CustomerModel Map(CustomerCreateDto source);

    [IncludeMappingConfiguration(nameof(MapCommon))]
    public override partial void Map(
        CustomerCreateDto source,
        CustomerModel destination);

    [IncludeMappingConfiguration(nameof(MapCommon))]
    public partial CustomerModel Map(CustomerUpdateDto source);

    [IncludeMappingConfiguration(nameof(MapCommon))]
    public partial void Map(
        CustomerUpdateDto source,
        CustomerModel destination);

    public void BeforeMap(CustomerUpdateDto source) { }
    public void AfterMap(
        CustomerUpdateDto source,
        CustomerModel destination) { }

    [UserMapping(Default = false)]
    private static string NormalizeCode(string code) =>
        code.Trim().ToUpperInvariant();
}
```

The shared base type makes its mapping configuration valid for both derived DTOs. The secondary interface's empty lifecycle methods are ABP contract plumbing here; shared behavior belongs in the included Mapperly configuration and `NormalizeCode`, where both mappings can use it. Confirm the exact interface requirements against the installed ABP version. If the input DTOs do not share an assignable base type, keep the helper in the shared mapper class but repeat the `MapProperty` attribute on each mapping method instead of using `IncludeMappingConfiguration`.

## Reuse another mapper with `UseMapper`

When a nested or collection element type already has a mapper, compose that mapper rather than copying its attributes and helpers into every parent mapper:

```csharp
[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class OrderLineToOrderLineDtoMapper
    : MapperBase<OrderLine, OrderLineDto>
{
    public override partial OrderLineDto Map(OrderLine source);
    public override partial void Map(OrderLine source, OrderLineDto destination);
}

[Mapper(RequiredMappingStrategy = RequiredMappingStrategy.Target)]
public partial class OrderToOrderDtoMapper
    : MapperBase<Order, OrderDto>
{
    [UseMapper]
    private readonly OrderLineToOrderLineDtoMapper _lineMapper;

    public OrderToOrderDtoMapper(
        OrderLineToOrderLineDtoMapper lineMapper)
    {
        _lineMapper = lineMapper;
    }

    public override partial OrderDto Map(Order source);
    public override partial void Map(Order source, OrderDto destination);
}
```

Mapperly considers mapping methods exposed by the `[UseMapper]` instance when generating the parent mapper, including compatible element mappings for nested collections. The field or property must be initialized by user code; in ABP mappers, constructor injection is usually the natural choice.

Use `UseMapper` when:

- the nested source/target pair already has a single authoritative mapper
- parent and nested mapper lifetimes and dependencies can be resolved by ABP dependency injection
- both create and update behavior of the reused mapper are appropriate for the parent mapping

Check these failure modes:

- Two reused mappers expose the same compatible source/target pair. Resolve the ambiguity with an explicitly selected/named mapping supported by the installed Mapperly version.
- The reused mapper is not registered or its constructor dependencies cannot be resolved.
- The parent uses `AutoUserMappings = false`. That setting also affects external mapping discovery; verify the installed version and explicitly select intended external methods where supported.
- Reusing an element mapper does not define aggregate collection merge semantics. Continue to test update-existing mappings for tracked entities and child collections.

For external static mapping methods, use Mapperly's separate `[UseStaticMapper(typeof(...))]` facility; do not attach `[UseMapper]` to an uninitialized instance merely to reach static methods.

## Collections and existing targets

Mapperly can generate element mappings, but ABP's selection of a custom mapper for collection types has varied across versions. First verify the installed version. Add an explicit collection `IObjectMapper<List<S>, List<T>>` only when a focused test proves the normal element mapper is not selected or when custom merge behavior is required.

For update mappings, decide whether collections are replaced, cleared and repopulated, or merged by identity. Do not accept generated behavior without a test when entities or tracked aggregates are involved.

## Cases needing an explicit design

Do not translate these mechanically:

- `ProjectTo` and expression-tree projections
- `Condition`, `PreCondition`, null substitution, or context-item behavior
- reference preservation and cycle handling
- inheritance and runtime polymorphism
- constructors/factories with domain invariants
- resolvers that call services or perform I/O
- mapping into EF Core tracked entities and child collections

Write down the old behavior, choose a supported Mapperly construct or explicit code, and test the observable result.
