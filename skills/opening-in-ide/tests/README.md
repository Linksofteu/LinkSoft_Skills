# opening-in-ide test harness

This folder contains both the human-readable scenario list and a runnable harness for the `opening-in-ide` scripts.

## Files

- `scenarios.md`: expected behaviors and edge cases
- `run-harness.py`: isolated validation harness for the Bash and PowerShell launchers

## Why this harness exists

The launcher scripts depend on external commands such as `rider`, `code`, `bash`, and `pwsh`. Running ad hoc checks against a developer machine can accidentally hit real installed IDE CLIs and produce misleading results.

This harness avoids that by:

- creating a temporary fixture tree under `/tmp`
- injecting fake `rider` and `code` commands into a controlled `PATH`
- forcing a minimal `PATH` for missing-CLI scenarios
- capturing launcher arguments instead of launching real IDEs

## What it covers

The harness exercises these script behaviors:

- IDE detection for none installed, one installed, and both installed
- Rider launch behavior for nearest `.sln`, `.csproj` fallback, direct open, directory open, and line numbers
- VS Code launch behavior for nearest `.code-workspace`, `.sln` directory fallback, `.csproj` directory fallback, direct open, and `--goto`
- invalid line handling and invalid path handling
- representative Bash and PowerShell launch paths
- explicit missing-CLI failure paths

It complements `scenarios.md`; it does not replace it.

## Requirements

- Linux or another environment with `/tmp`
- `python3`
- `bash`
- `pwsh`

The harness does not require real Rider or VS Code installations.

## Usage

From the repository root:

```bash
python3 skills/opening-in-ide/tests/run-harness.py
```

The script prints a JSON summary like:

```json
{
  "base": "/tmp/opening-in-ide-tests-xxxxxx",
  "passed": 29,
  "failed": 0,
  "failures": []
}
```

The process exits with code `0` when all checks pass and `1` when any check fails.

## Notes

- The temporary fixture directory is left in place to make failures easier to inspect.
- The harness currently focuses on script-level behavior, not agent-level prompting logic.
