---
name: opening-in-ide
description: Opens a file or folder in a supported IDE using the nearest workspace or project context when available. Use when the user asks to open code in Rider, VS Code, or a generic IDE from the CLI.
license: MIT
compatibility: Intended for OpenCode/Codex-style agents on Linux, macOS, or Windows. Requires Bash or PowerShell plus supported IDE CLIs on PATH (`rider` on Unix-like systems; `rider`, `rider.bat`, or `rider64.exe` on Windows; `code` on Unix-like systems; `code` or `code.cmd` on Windows).
metadata:
  author: David Orolin
  version: "0.9.0"
---

## Purpose

Use this skill when the user wants to open a file or project in a supported IDE from the CLI, while preserving solution, project, or workspace context when possible.

## Behavior

1. Accept a file or directory path (default `.`) and an optional line number.
2. When the user names a specific supported IDE, use the matching launcher only.
3. When the user asks for a generic IDE:
   - Run the installed-IDE detection script for the current platform.
   - If no supported IDE is installed, report that none of the supported IDEs are available.
   - If exactly one supported IDE is installed, use it without asking.
   - If multiple supported IDEs are installed, ask the user which one to use.
   - Prefer an interactive multi-choice prompt when the runtime supports it.
   - Populate the choices from the detected installed IDEs instead of hardcoding a fixed set.
   - If the runtime does not support interactive choices, ask a single concise text question listing the available installed IDEs.
   - Do not guess when multiple valid installed IDEs are available and the user did not specify one.
4. If the user explicitly requests an IDE that is not installed, return a clear error and do not fall back to another IDE.
5. Launch the chosen IDE in non-blocking mode (fire-and-forget) so the terminal session is not held open.

## IDE-specific behavior

### Rider

1. Walk upward from the target location to find the nearest directory containing one or more `*.sln` files.
2. If a solution is found, open Rider with the solution and target path.
3. If no solution is found, fall back to the nearest `*.csproj`.
4. If neither is found, open the target directly.
5. When multiple matching files exist in one directory, prefer the file whose basename matches the directory name; otherwise choose alphabetically.

### VS Code

1. Walk upward from the target location to find the nearest directory containing one or more `*.code-workspace` files.
2. If a workspace is found, open VS Code with that workspace as context.
3. If no workspace is found, fall back to the nearest `*.sln` and use that file's directory as context.
4. If no solution is found, fall back to the nearest `*.csproj` and use that file's directory as context.
5. If neither is found, open the target directly.
6. When opening a file at a line, use VS Code `--goto` behavior.
7. When multiple matching files exist in one directory, prefer the file whose basename matches the directory name; otherwise choose alphabetically.

## Scripts

Use:

- Linux/macOS IDE detection: `./skills/opening-in-ide/scripts/list-installed-ides.sh`
- Windows IDE detection: `./skills/opening-in-ide/scripts/list-installed-ides.ps1`
- Linux/macOS Rider launcher: `./skills/opening-in-ide/scripts/open-in-rider.sh <path> [--line <n>]`
- Windows Rider launcher: `./skills/opening-in-ide/scripts/open-in-rider.ps1 <path> [--line <n>]`
- Linux/macOS VS Code launcher: `./skills/opening-in-ide/scripts/open-in-code.sh <path> [--line <n>]`
- Windows VS Code launcher: `./skills/opening-in-ide/scripts/open-in-code.ps1 <path> [--line <n>]`

Examples:

- `./skills/opening-in-ide/scripts/list-installed-ides.sh`
- `./skills/opening-in-ide/scripts/open-in-rider.sh src/MyFile.cs --line 120`
- `./skills/opening-in-ide/scripts/open-in-code.sh src/MyFile.cs --line 120`
- `./skills/opening-in-ide/scripts/open-in-rider.ps1 .`
- `./skills/opening-in-ide/scripts/open-in-code.ps1 .`

## Notes

- Current supported IDE identifiers are `rider` and `code`.
- The detection scripts print one installed IDE per line and succeed even when none are installed.
- Rider requires CLI availability on `PATH` (`rider` on Unix-like systems; `rider`, `rider.bat`, or `rider64.exe` on Windows).
- VS Code requires CLI availability on `PATH` (`code` on Unix-like systems; `code` or `code.cmd` on Windows).
- When more IDEs are added later, keep the generic-selection flow data-driven: detect installed IDEs, present only valid installed options, and preserve the same interactive-choice-then-fallback behavior.
