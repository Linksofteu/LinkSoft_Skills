# opening-in-ide implementation

## Goal

`skills/opening-in-ide` now covers both JetBrains Rider and Visual Studio Code while keeping platform scripts separate and behavior explicit.

## Implemented behavior

### Supported IDEs

- `rider`
- `code`

This pass intentionally excludes Cursor, Windsurf, and other VS Code-derived editors.

### Generic "open in IDE" requests

The skill documentation now defines this selection flow:

1. Detect installed supported IDEs with `list-installed-ides.sh` or `list-installed-ides.ps1`.
2. If none are installed, report that no supported IDE is available.
3. If exactly one is installed, use it without asking.
4. If multiple are installed, ask the user which installed IDE to use.

### Explicit IDE requests

- Explicit Rider requests use only Rider.
- Explicit VS Code requests use only VS Code.
- Missing requested CLIs return a clear error.
- No silent fallback occurs.

## Script layout

The implementation keeps focused per-IDE launchers plus small detection scripts:

- `skills/opening-in-ide/scripts/open-in-rider.sh`
- `skills/opening-in-ide/scripts/open-in-rider.ps1`
- `skills/opening-in-ide/scripts/open-in-code.sh`
- `skills/opening-in-ide/scripts/open-in-code.ps1`
- `skills/opening-in-ide/scripts/list-installed-ides.sh`
- `skills/opening-in-ide/scripts/list-installed-ides.ps1`

Detection output remains machine-friendly:

```text
rider
code
```

Each installed supported IDE prints once on its own line. No installed IDEs produce no output and still exit successfully.

## IDE-specific behavior

### Rider

Rider launchers keep the previous semantics:

1. Accept a file or directory path, defaulting to `.`.
2. Support optional line number.
3. Search upward for nearest `*.sln`.
4. Fall back to nearest `*.csproj`.
5. Otherwise open the target directly.
6. Launch non-blocking.

When multiple matching files exist in one directory, they prefer a basename matching the directory name, then alphabetical order.

### VS Code

VS Code launchers use the closest equivalent context behavior:

1. Accept a file or directory path, defaulting to `.`.
2. Support optional line number.
3. Search upward for nearest `*.code-workspace`.
4. Fall back to nearest `*.sln` directory.
5. Fall back again to nearest `*.csproj` directory.
6. Otherwise open the target directly.
7. Use `--goto` for file-and-line opens.
8. Launch non-blocking.

## Documentation updates

The implementation updates:

- `skills/opening-in-ide/SKILL.md`
- `skills/opening-in-ide/README.md`
- `skills/opening-in-ide/tests/scenarios.md`
- `skills/opening-in-ide/tests/run-harness.py`
- `skills/opening-in-ide/tests/README.md`

Those files now describe the broader skill trigger, generic IDE selection flow, explicit missing-IDE behavior, launcher layout, the reusable isolated test harness, and the new versioned skill metadata.

## Validation guidance

Recommended follow-up validation remains:

- `npx skills add . --list`
- `npx skills add . --skill opening-in-ide`
- Bash syntax checks for `.sh` scripts
- PowerShell parse or syntax checks for `.ps1` scripts

Because `npx skills add . --skill opening-in-ide` may create local artifacts, review the working tree before and after running it.
