# opening-in-rider

Open a file or folder in JetBrains Rider from an agent workflow, using the nearest `.sln` context when available (then `.csproj`, then direct open).

The launcher is non-blocking (fire-and-forget) so terminal-based agents can continue immediately after Rider opens.

## Contents

- `SKILL.md`: Agent-facing skill instructions and metadata
- `scripts/open-in-rider.sh`: Linux/macOS launcher script
- `scripts/open-in-rider.ps1`: Windows PowerShell launcher script
- `tests/scenarios.md`: Behavior and edge-case test scenarios

## Prerequisites

- JetBrains Rider installed
- Rider CLI launcher available on `PATH`
  - Unix-like: `rider`
  - Windows: `rider`, `rider.bat`, or `rider64.exe`

## Usage

Linux/macOS:

```bash
./skills/opening-in-rider/scripts/open-in-rider.sh <path> [--line <n>]
```

Windows (PowerShell):

```powershell
./skills/opening-in-rider/scripts/open-in-rider.ps1 <path> [--line <n>]
```

Examples:

```bash
./skills/opening-in-rider/scripts/open-in-rider.sh src/MyFile.cs
./skills/opening-in-rider/scripts/open-in-rider.sh src/MyFile.cs --line 120
./skills/opening-in-rider/scripts/open-in-rider.sh .
```

```powershell
./skills/opening-in-rider/scripts/open-in-rider.ps1 src/MyFile.cs
./skills/opening-in-rider/scripts/open-in-rider.ps1 src/MyFile.cs --line 120
./skills/opening-in-rider/scripts/open-in-rider.ps1 .
```

## Selection behavior

1. Search upward from the target path for nearest `*.sln`
2. If no solution exists, search for nearest `*.csproj`
3. If neither exists, open the target directly

When multiple `.sln`/`.csproj` files exist in a directory:

- Prefer the one whose basename matches the directory name
- Otherwise choose alphabetically

## Troubleshooting

- `Rider CLI not found on PATH`: configure Rider launcher in IDE settings and restart shell
- `path does not exist`: verify the provided file/folder path
- `--line must be a positive integer`: pass values like `1`, `120`, `999`
