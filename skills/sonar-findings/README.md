# Sonar findings

Read-only retrieval of SonarQube issues and security hotspots for a branch or PR, with complete pagination and explicit partial-result reporting. Author: David Orolin. Repository MIT license applies.

## Contents

- `SKILL.md`: agent procedure and safety boundaries.
- `scripts/fetch_findings.py`: dependency-free Python 3.9+ API client.
- `scripts/test_fetch_findings.py`: offline regression tests.
- `evals/evals.json`: agent workflow evaluation cases.

## Credentials and portability

Configure `SONAR_TOKEN` through your existing secret manager/environment, or provide a UTF-8 token file. Do not put token values in shell commands or chat. No fixed secret-file location is required. An explicit `--token-file` takes precedence over environment configuration; otherwise `SONAR_TOKEN` takes precedence over `SONAR_TOKEN_FILE`.

Linux/macOS (Python 3):

```sh
python3 skills/sonar-findings/scripts/fetch_findings.py --url https://sonar.example.com --project my-project --branch feature/example --token-file "$HOME/.config/company/sonar-token"
```

Windows (Python launcher):

```powershell
py -3 skills/sonar-findings/scripts/fetch_findings.py --url https://sonar.example.com --project my-project --pull-request 123 --token-file "$env:LOCALAPPDATA\Company\sonar-token"
```

These paths are examples, not locations the agent should search. Restrict file access using the OS's permissions/ACLs. Authentication is Bearer over verified HTTPS; redirects are refused to avoid forwarding credentials elsewhere.

By default a unique `sonar-findings-*` directory is created using `tempfile.mkdtemp()` (respects the OS temporary-directory configuration). `--output` accepts a new directory on any OS and refuses overwriting an existing one.

Outputs include analysis discovery, raw issue/hotspot pages, flattened findings, hotspot details, quality gate status, and a manifest with counts/errors. No credentials are stored. Snapshot totals/duplicate keys are checked; avoid concurrent analysis publication during retrieval.

Exit codes: **0** complete; **2** partial (inspect manifest); **1** setup, authentication, or analysis-selection failure. A forbidden hotspot request does not discard successfully fetched issues. Rule metadata and issue comments are retained via `additionalFields=_all`; this is not an export of every issue changelog or source file.

## Validation

```sh
python3 skills/sonar-findings/scripts/test_fetch_findings.py
npx skills add . --list
npx skills add . --skill sonar-findings
```

Offline tests use mocked HTTP results, not real secrets. Live retrieval is optional and requires explicit credentials and target selection. Agent eval cases describe expected behavior; they are not claimed as executed benchmarks.
