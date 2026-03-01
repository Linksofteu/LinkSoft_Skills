---
name: opening-in-rider
description: Opens a file or folder in JetBrains Rider using the nearest .sln or .csproj context when available. Use when the user asks to open code in Rider from the CLI.
license: MIT
compatibility: Intended for OpenCode/Codex-style agents on Linux, macOS, or Windows. Requires Bash or PowerShell and JetBrains Rider CLI on PATH (`rider` on Unix-like systems; `rider`, `rider.bat`, or `rider64.exe` on Windows).
metadata:
  author: David Orolin
  version: "0.7.0"
---

## Purpose

Use this skill when the user wants to open a file or project in JetBrains Rider from the CLI, while preserving solution context.

## Behavior

1. Accept a file or directory path (default `.`).
2. Walk upward from that location to find the nearest directory containing one or more `*.sln` files.
3. If a solution is found, open Rider with the solution and target path.
4. If no solution is found, fall back to nearest `*.csproj`.
5. If neither is found, open the target directly.
6. Launch Rider in non-blocking mode (fire-and-forget) so the terminal session is not held open.

## Scripts

Use:

- Linux/macOS (Bash): `./skills/opening-in-rider/scripts/open-in-rider.sh <path> [--line <n>]`
- Windows (PowerShell): `./skills/opening-in-rider/scripts/open-in-rider.ps1 <path> [--line <n>]`

Examples:

- `./skills/opening-in-rider/scripts/open-in-rider.sh src/MyFile.cs`
- `./skills/opening-in-rider/scripts/open-in-rider.sh src/MyFile.cs --line 120`
- `./skills/opening-in-rider/scripts/open-in-rider.sh .`
- `./skills/opening-in-rider/scripts/open-in-rider.ps1 src/MyFile.cs`
- `./skills/opening-in-rider/scripts/open-in-rider.ps1 src/MyFile.cs --line 120`
- `./skills/opening-in-rider/scripts/open-in-rider.ps1 .`

## Notes

- Requires Rider CLI to be available on `PATH` (`rider` on Unix-like systems; `rider`, `rider.bat`, or `rider64.exe` on Windows).
- When multiple `.sln` files exist in the same directory, the script prefers one whose base name matches that directory name; otherwise it uses alphabetical order.
