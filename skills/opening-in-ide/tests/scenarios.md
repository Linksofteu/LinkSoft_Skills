# Test Scenarios for opening-in-ide

## Scenario: Generic request with no supported IDEs installed

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in an IDE.

**Expected behaviors:**

1. Detects supported IDE availability
   - **Minimum:** Runs `list-installed-ides` for the current platform
   - **Quality criteria:**
     - Handles zero-line output as "none installed"
     - Returns a clear error without trying another launcher

---

## Scenario: Generic request with exactly one installed IDE

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in an IDE.

**Expected behaviors:**

1. Auto-selects the only installed supported IDE
   - **Minimum:** Uses the matching launcher without asking
   - **Quality criteria:**
     - Does not prompt the user unnecessarily
     - Chooses only from `rider` or `code`

---

## Scenario: Generic request with multiple installed IDEs

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in an IDE.

**Expected behaviors:**

1. Asks the user to choose an IDE
   - **Minimum:** Prompts when both `rider` and `code` are installed
   - **Quality criteria:**
     - Mentions only installed supported IDEs
     - Does not choose one silently

## Scenario: Open file in nearest solution

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in Rider.

**Expected behaviors:**

1. Uses the skill script with a file path
   - **Minimum:** Runs `scripts/open-in-rider.sh` (Linux/macOS) or `scripts/open-in-rider.ps1` (Windows)
   - **Quality criteria:**
     - Selects script matching host OS/shell
     - Passes the file path argument exactly once
     - Uses absolute or valid relative path

2. Finds nearest `.sln`
   - **Minimum:** Opens Rider with solution context
   - **Quality criteria:**
     - Walks parent directories from file location
     - Chooses nearest directory containing `*.sln`
      - Includes both solution and file in Rider arguments

3. Returns without blocking terminal session
   - **Minimum:** Script exits immediately after launching Rider
   - **Quality criteria:**
     - Agent can continue interacting in the same terminal
     - Rider process is detached from script lifecycle

---

## Scenario: Explicit Rider request when Rider is not installed

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in Rider.

**Expected behaviors:**

1. Returns Rider-specific error
   - **Minimum:** Reports that Rider is unavailable
   - **Quality criteria:**
     - Does not fall back to VS Code
     - Mentions expected Rider command names

---

## Scenario: Open file at specific line

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` at line `120` in Rider.

**Expected behaviors:**

1. Passes line argument
   - **Minimum:** Uses `--line 120`
   - **Quality criteria:**
     - Keeps argument order valid for script
     - Opens file in solution/project context when available

2. Validates line number
   - **Minimum:** Accepts positive integers
   - **Quality criteria:**
     - Rejects missing `--line` value
     - Rejects non-numeric values with clear error

---

## Scenario: Open directory in nearest solution

**Difficulty:** Easy

**Query:** Open current directory in Rider.

**Expected behaviors:**

1. Handles directory target
   - **Minimum:** Accepts `.` as default or explicit path
   - **Quality criteria:**
     - Resolves directory path
     - Finds nearest `.sln` and opens that solution
     - Falls back to `.csproj` or directory when needed

---

## Scenario: Fallback to nearest project

**Difficulty:** Medium

**Query:** Open a file where no `.sln` exists but a `.csproj` exists in parent directories.

**Expected behaviors:**

1. Uses `.csproj` fallback
   - **Minimum:** Opens Rider with nearest project
   - **Quality criteria:**
     - Searches for `.sln` first
     - Uses nearest `.csproj` only when no solution is found
     - Includes file path when target is a file

---

## Scenario: No solution or project found

**Difficulty:** Medium

**Query:** Open `README.md` in a non-.NET directory tree.

**Expected behaviors:**

1. Falls back to direct open
   - **Minimum:** Opens Rider with target path only
   - **Quality criteria:**
     - Does not fail when no `.sln`/`.csproj` exists
     - Uses `--line` with direct file open when provided

---

## Scenario: Multiple solution files in one directory

**Difficulty:** Hard

**Query:** Open a file in a folder containing `App.sln` and `src.sln` where directory name is `src`.

**Expected behaviors:**

1. Deterministic solution choice
   - **Minimum:** Picks one solution consistently
   - **Quality criteria:**
     - Prefers solution whose basename matches directory name (`src.sln`)
     - Otherwise falls back to alphabetical order

---

## Scenario: Explicit VS Code request when VS Code is installed

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in VS Code.

**Expected behaviors:**

1. Uses VS Code launcher
   - **Minimum:** Runs `scripts/open-in-code.sh` (Linux/macOS) or `scripts/open-in-code.ps1` (Windows)
   - **Quality criteria:**
     - Selects script matching host OS/shell
     - Uses nearest workspace or project-folder context when available

---

## Scenario: Explicit VS Code request when VS Code is not installed

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` in VS Code.

**Expected behaviors:**

1. Returns VS Code-specific error
   - **Minimum:** Reports that VS Code is unavailable
   - **Quality criteria:**
     - Does not fall back to Rider
     - Mentions expected VS Code command names

---

## Scenario: Rider CLI missing

**Difficulty:** Edge-case

**Query:** Open `src/MyFile.cs` on a machine without Rider CLI on PATH.

**Expected behaviors:**

1. Fails with actionable error
   - **Minimum:** Returns non-zero exit
   - **Quality criteria:**
      - Error clearly states Rider CLI is not available
      - Error message mentions expected command names

---

## Scenario: VS Code line-number open

**Difficulty:** Easy

**Query:** Open `src/MyFile.cs` at line `120` in VS Code.

**Expected behaviors:**

1. Uses `--goto`
   - **Minimum:** Opens with `--goto`
   - **Quality criteria:**
     - Passes `path:line` in VS Code format
     - Preserves workspace or project-folder context when available

---

## Scenario: Rider .sln fallback to .csproj

**Difficulty:** Medium

**Query:** Open a file in Rider where no `.sln` exists but a `.csproj` exists in parent directories.

**Expected behaviors:**

1. Uses `.csproj` fallback
   - **Minimum:** Opens Rider with nearest project
   - **Quality criteria:**
     - Searches for `.sln` first
     - Uses nearest `.csproj` only when no solution is found

---

## Scenario: VS Code workspace fallback to project-folder context

**Difficulty:** Medium

**Query:** Open a file in VS Code where no `.code-workspace` exists, but a parent directory contains a `.sln` or `.csproj`.

**Expected behaviors:**

1. Uses project-folder context
   - **Minimum:** Opens VS Code with the solution or project directory as context
   - **Quality criteria:**
     - Searches for `.code-workspace` first
     - Falls back to `.sln` directory before `.csproj` directory
     - Opens the requested file inside that context

---

## Scenario: Invalid target path

**Difficulty:** Edge-case

**Query:** Open `/path/that/does/not/exist.cs`.

**Expected behaviors:**

1. Reports path error
   - **Minimum:** Returns non-zero exit with file-not-found style message
   - **Quality criteria:**
      - Includes the invalid path in the error
      - Does not invoke Rider or VS Code when path is invalid
