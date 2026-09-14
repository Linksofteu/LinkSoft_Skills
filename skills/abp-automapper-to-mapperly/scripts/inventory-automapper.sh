#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: inventory-automapper.sh [--root PATH]' \
    '' \
    'Read-only scan for AutoMapper integration and migration-sensitive constructs.' \
    'Requires: bash, rg'
}

scan_root='.'
while (($# > 0)); do
  case "$1" in
    --root)
      if (($# < 2)); then
        printf 'error: --root requires a path\n' >&2
        exit 2
      fi
      scan_root=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v rg >/dev/null 2>&1; then
  printf 'error: rg (ripgrep) is required\n' >&2
  exit 2
fi

if [[ ! -d "$scan_root" ]]; then
  printf 'error: root is not a directory: %s\n' "$scan_root" >&2
  exit 2
fi

search_globs=(
  --glob '*.cs'
  --glob '*.csproj'
  --glob 'Directory.Packages.props'
  --glob '!**/bin/**'
  --glob '!**/obj/**'
  --glob '!**/node_modules/**'
)

print_matches() {
  local title=$1
  local pattern=$2
  printf '\n## %s\n\n' "$title"
  local matches
  matches=$(rg -n --color never "${search_globs[@]}" "$pattern" "$scan_root" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches"
  else
    printf '_No matches._\n'
  fi
}

printf '# AutoMapper migration inventory\n\n'
printf 'Root: `%s`\n' "$scan_root"

print_matches 'Packages and ABP registration' \
  'Volo\.Abp\.AutoMapper|<PackageReference[^>]+AutoMapper|AbpAutoMapperModule|AddAutoMapperObjectMapper|AbpAutoMapperOptions'
print_matches 'Profiles and mapping declarations' \
  '\bProfile\b|CreateMap[<(]|ForMember[<(]|ForPath[<(]|IncludeMembers[<(]|IncludeBase[<(]|ReverseMap[<(]'
print_matches 'Converters, resolvers, conditions, and hooks' \
  'ConvertUsing[<(]|ITypeConverter<|IValueResolver<|IMemberValueResolver<|Condition[<(]|PreCondition[<(]|NullSubstitute[<(]|BeforeMap[<(]|AfterMap[<(]|ResolutionContext'
print_matches 'Direct AutoMapper call sites and projections' \
  'using AutoMapper|\bIMapper\b|ProjectTo[<(]|Mapper\.Map[<(]'
print_matches 'ABP mapping helpers and tests' \
  'MapExtraProperties[<(]|IgnoreAuditProperties[<(]|AssertConfigurationIsValid|AutoMapperProfile|ProfileTest'
