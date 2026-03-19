#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import textwrap
import time
from dataclasses import asdict, dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SKILL_ROOT = REPO_ROOT / "skills" / "opening-in-ide"
SCRIPTS_DIR = SKILL_ROOT / "scripts"
BASE_PATH = "/usr/bin:/bin"


@dataclass
class Result:
    name: str
    ok: bool
    details: dict[str, object]


class Harness:
    def __init__(self) -> None:
        self.base = Path(tempfile.mkdtemp(prefix="opening-in-ide-tests-", dir="/tmp"))
        self.fixture = self.base / "fixture"
        self.bin_dir = self.base / "bin"
        self.logs = self.base / "logs"
        self.results: list[Result] = []

        self.fixture.mkdir()
        self.bin_dir.mkdir()
        self.logs.mkdir()

        for log_name in ("rider.log", "code.log"):
            (self.logs / log_name).write_text("", encoding="utf-8")

        self._write_fake_cli("rider", "rider.log")
        self._write_fake_cli("code", "code.log")
        self._build_fixture_tree()

    def _write_fake_cli(self, command_name: str, log_name: str) -> None:
        path = self.bin_dir / command_name
        path.write_text(
            textwrap.dedent(
                f"""#!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' \"$*\" >> \"{(self.logs / log_name).as_posix()}\"
                """
            ),
            encoding="utf-8",
        )
        path.chmod(0o755)

    def _build_fixture_tree(self) -> None:
        self.root = self.fixture / "repo"
        (self.root / "src").mkdir(parents=True)
        (self.root / "src" / "MyFile.cs").write_text("// file\n", encoding="utf-8")
        (self.root / "README.md").write_text("# readme\n", encoding="utf-8")
        (self.root / "repo.sln").write_text("\n", encoding="utf-8")
        (self.root / "project.csproj").write_text("<Project />\n", encoding="utf-8")
        (self.root / "repo.code-workspace").write_text("{}\n", encoding="utf-8")

        self.fallback = self.fixture / "fallback"
        (self.fallback / "nested" / "deeper").mkdir(parents=True)
        (self.fallback / "nested" / "deeper" / "Lib.cs").write_text("// lib\n", encoding="utf-8")
        (self.fallback / "Lib.csproj").write_text("<Project />\n", encoding="utf-8")

        self.nosln = self.fixture / "nosln"
        (self.nosln / "docs").mkdir(parents=True)
        (self.nosln / "docs" / "readme.md").write_text("x\n", encoding="utf-8")

        self.multi = self.fixture / "multi" / "src"
        self.multi.mkdir(parents=True)
        (self.multi / "Program.cs").write_text("// program\n", encoding="utf-8")
        (self.multi / "App.sln").write_text("\n", encoding="utf-8")
        (self.multi / "src.sln").write_text("\n", encoding="utf-8")

        self.missing_path = self.fixture / "does-not-exist.cs"

    def script(self, name: str) -> Path:
        return SCRIPTS_DIR / name

    def run(self, command: list[str], extra_path: Path | None = None) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["PATH"] = f"{extra_path}:{BASE_PATH}" if extra_path else BASE_PATH
        return subprocess.run(command, text=True, capture_output=True, env=env)

    def run_bash(self, script_name: str, *args: object, extra_path: Path | None = None) -> subprocess.CompletedProcess[str]:
        return self.run(["bash", str(self.script(script_name)), *map(str, args)], extra_path=extra_path)

    def run_pwsh(self, script_name: str, *args: object, extra_path: Path | None = None) -> subprocess.CompletedProcess[str]:
        return self.run(["pwsh", "-NoProfile", "-File", str(self.script(script_name)), *map(str, args)], extra_path=extra_path)

    def read_log(self, name: str) -> list[str]:
        path = self.logs / name
        time.sleep(0.2)
        return [line for line in path.read_text(encoding="utf-8").splitlines() if line]

    def clear_logs(self) -> None:
        for name in ("rider.log", "code.log"):
            (self.logs / name).write_text("", encoding="utf-8")

    def record(self, name: str, ok: bool, **details: object) -> None:
        self.results.append(Result(name=name, ok=ok, details=details))

    def make_single_cli_dir(self, command_name: str) -> Path:
        target_dir = self.base / f"only-{command_name}"
        target_dir.mkdir(exist_ok=True)
        shutil.copy2(self.bin_dir / command_name, target_dir / command_name)
        (target_dir / command_name).chmod(0o755)
        return target_dir

    def run_all(self) -> dict[str, object]:
        target = self.root / "src" / "MyFile.cs"
        direct_target = self.nosln / "docs" / "readme.md"
        fallback_target = self.fallback / "nested" / "deeper" / "Lib.cs"
        multi_target = self.multi / "Program.cs"
        only_rider = self.make_single_cli_dir("rider")
        only_code = self.make_single_cli_dir("code")

        res = self.run_bash("list-installed-ides.sh")
        self.record("bash detect none", res.returncode == 0 and res.stdout.strip() == "", code=res.returncode, stdout=res.stdout.strip(), stderr=res.stderr.strip())

        res = self.run_bash("list-installed-ides.sh", extra_path=self.bin_dir)
        self.record("bash detect rider+code", res.returncode == 0 and res.stdout.splitlines() == ["rider", "code"], code=res.returncode, stdout=res.stdout.splitlines(), stderr=res.stderr.strip())

        res = self.run_bash("list-installed-ides.sh", extra_path=only_rider)
        self.record("bash detect rider only", res.returncode == 0 and res.stdout.splitlines() == ["rider"], code=res.returncode, stdout=res.stdout.splitlines(), stderr=res.stderr.strip())

        res = self.run_pwsh("list-installed-ides.ps1")
        self.record("pwsh detect none", res.returncode == 0 and res.stdout.strip() == "", code=res.returncode, stdout=res.stdout.strip(), stderr=res.stderr.strip())

        res = self.run_pwsh("list-installed-ides.ps1", extra_path=self.bin_dir)
        self.record("pwsh detect rider+code", res.returncode == 0 and res.stdout.splitlines() == ["rider", "code"], code=res.returncode, stdout=res.stdout.splitlines(), stderr=res.stderr.strip())

        res = self.run_pwsh("list-installed-ides.ps1", extra_path=only_code)
        self.record("pwsh detect code only", res.returncode == 0 and res.stdout.splitlines() == ["code"], code=res.returncode, stdout=res.stdout.splitlines(), stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", target, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider nearest sln", res.returncode == 0 and rider_log[-1] == f"{self.root / 'repo.sln'} {target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", target, "--line", "120", extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider line open", res.returncode == 0 and rider_log[-1] == f"{self.root / 'repo.sln'} --line 120 {target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", self.root, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider directory open", res.returncode == 0 and rider_log[-1] == f"{self.root / 'repo.sln'}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", fallback_target, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider csproj fallback", res.returncode == 0 and rider_log[-1] == f"{self.fallback / 'Lib.csproj'} {fallback_target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", direct_target, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider direct open", res.returncode == 0 and rider_log[-1] == f"{direct_target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-rider.sh", multi_target, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("bash rider best sln match", res.returncode == 0 and rider_log[-1] == f"{self.multi / 'src.sln'} {multi_target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        res = self.run_bash("open-in-rider.sh", target)
        self.record("bash rider missing cli", res.returncode == 127 and "Rider CLI not found" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        res = self.run_bash("open-in-rider.sh", target, "--line", "abc", extra_path=self.bin_dir)
        self.record("bash rider invalid line", res.returncode == 2 and "--line must be a positive integer" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        res = self.run_bash("open-in-rider.sh", self.missing_path, extra_path=self.bin_dir)
        self.record("bash rider invalid path", res.returncode == 2 and "path does not exist" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-code.sh", target, extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("bash code workspace context", res.returncode == 0 and code_log[-1] == f"{self.root / 'repo.code-workspace'} {target}", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-code.sh", target, "--line", "120", extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("bash code goto line", res.returncode == 0 and code_log[-1] == f"{self.root / 'repo.code-workspace'} --goto {target}:120", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        (self.root / "repo.code-workspace").unlink()
        self.clear_logs()
        res = self.run_bash("open-in-code.sh", target, extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("bash code sln dir fallback", res.returncode == 0 and code_log[-1] == f"{self.root} {target}", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        (self.root / "repo.sln").unlink()
        self.clear_logs()
        res = self.run_bash("open-in-code.sh", target, extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("bash code csproj dir fallback", res.returncode == 0 and code_log[-1] == f"{self.root} {target}", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_bash("open-in-code.sh", direct_target, extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("bash code direct open", res.returncode == 0 and code_log[-1] == f"{direct_target}", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        res = self.run_bash("open-in-code.sh", target)
        self.record("bash code missing cli", res.returncode == 127 and "VS Code CLI not found" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        res = self.run_bash("open-in-code.sh", self.missing_path, extra_path=self.bin_dir)
        self.record("bash code invalid path", res.returncode == 2 and "path does not exist" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        (self.root / "repo.code-workspace").write_text("{}\n", encoding="utf-8")
        (self.root / "repo.sln").write_text("\n", encoding="utf-8")

        self.clear_logs()
        res = self.run_pwsh("open-in-rider.ps1", target, extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("pwsh rider nearest sln", res.returncode == 0 and rider_log[-1] == f"{self.root / 'repo.sln'} {target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_pwsh("open-in-rider.ps1", target, "--line", "120", extra_path=self.bin_dir)
        rider_log = self.read_log("rider.log")
        self.record("pwsh rider line open", res.returncode == 0 and rider_log[-1] == f"{self.root / 'repo.sln'} --line 120 {target}", code=res.returncode, log=rider_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_pwsh("open-in-code.ps1", target, extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("pwsh code workspace context", res.returncode == 0 and code_log[-1] == f"{self.root / 'repo.code-workspace'} {target}", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        self.clear_logs()
        res = self.run_pwsh("open-in-code.ps1", target, "--line", "120", extra_path=self.bin_dir)
        code_log = self.read_log("code.log")
        self.record("pwsh code goto line", res.returncode == 0 and code_log[-1] == f"{self.root / 'repo.code-workspace'} --goto {target}:120", code=res.returncode, log=code_log, stderr=res.stderr.strip())

        res = self.run_pwsh("open-in-code.ps1", target)
        self.record("pwsh code missing cli", res.returncode == 127 and "VS Code CLI not found" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        res = self.run_pwsh("open-in-rider.ps1", target)
        self.record("pwsh rider missing cli", res.returncode == 127 and "Rider CLI not found" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        res = self.run_pwsh("open-in-code.ps1", self.missing_path, extra_path=self.bin_dir)
        self.record("pwsh code invalid path", res.returncode == 2 and "path does not exist" in res.stderr, code=res.returncode, stderr=res.stderr.strip())

        failures = [asdict(result) for result in self.results if not result.ok]
        return {
            "base": str(self.base),
            "passed": len(self.results) - len(failures),
            "failed": len(failures),
            "failures": failures,
        }


def main() -> int:
    harness = Harness()
    summary = harness.run_all()
    print(json.dumps(summary, indent=2))
    return 1 if summary["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
