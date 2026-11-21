# Testing and CI

## Reproduce the checks

Work from the root of a Git checkout. The checks use `git ls-files` to select
repository sources. The Windows test process needs Git on its own PATH.
See [local setup](../README.md#local-environment-no-docker-required).

### Source and documentation

In WSL the following commands compile the tracked Python files in memory, check
local Markdown links and run the documentation regression tests. On Windows
the workflow passes the same Python compiler loop to `python -` using a
PowerShell here-string. [Workflow](../.github/workflows/ci.yml)

```bash
(
set -e
python3 - <<'PY'
from pathlib import Path
from subprocess import check_output

names = check_output(["git", "ls-files", "-z", "--", "*.py"]).decode().split("\0")
for name in filter(None, names):
    compile(Path(name).read_bytes(), name, "exec")
PY
python3 -B build/check_docs.py
python3 -B -m unittest discover -s tests -p test_documentation.py -v
)
```

In a Windows PowerShell process at the checkout root, run the parameter check
below. It reads the scripts' syntax trees. These documentation checks work
offline without Pester or PSScriptAnalyzer.

```powershell
.\build\Check-DocumentationCommands.ps1
```

### Windows unit and integration tests

For the first download, PowerShell 7 needs `Save-Module` from PowerShellGet,
an existing NuGet provider and access to PowerShell Gallery. The bootstrap
saves Pester 5.7.1 and PSScriptAnalyzer 1.24.0 in `out/dependencies/`. With
those versions cached, the check script runs offline under either edition.

| Step | Windows executable | Arguments from the checkout root |
| --- | --- | --- |
| Bootstrap dependencies | `pwsh.exe` | `-NoProfile -NonInteractive -File .\build\Install-TestDependencies.ps1` |
| Windows PowerShell 5.1 | `powershell.exe` | `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\build\Invoke-Checks.ps1` |
| PowerShell 7 | `pwsh.exe` | `-NoProfile -NonInteractive -File .\build\Invoke-Checks.ps1` |

For unattended execution, configure a Windows process launcher with
`UseShellExecute = false` and `CreateNoWindow = true`. Give the Windows child
Windows-form paths, including when the caller is in WSL. Capture stdout and stderr and use
the PowerShell child's exit code after it finishes. A terminal wrapper can
return success even when that child fails.

## What is checked

- The workflow separately syntax-compiles every tracked Python file without
  importing or running operational helpers. Invoke-Checks.ps1 itself checks
  PowerShell; it does not run the Python syntax/doc checks.
- Documentation checks validate current relative Markdown links/fragments,
  regression-test the checker, and compare documented parameter names with
  PowerShell ASTs. They neither fetch external links nor execute script examples.
- All repository PowerShell scripts/data files are parsed under the selected
  engine, including archived files. Parsing never executes the archive.
- Maintained code receives safety lint for automatic-variable assignment and
  `Invoke-Expression`. This is a targeted safety gate, not a claim that every
  possible analyzer rule has passed.
- Unit tests cover configuration, Windows command quoting and ambiguous paths,
  task access errors, headless task actions, SQX status/error/readiness parsing,
  native exit propagation, network-specific failure counters, and INI sections.
- Fixture integration tests rebuild synthetic ZIPs, test transactional overwrite
  and backup behavior, and stage a complete toolkit only into Pester TestDrive.
- Operational script tests mock process, HTTP and task operations. They check
  `-WhatIf`, host checks, explicit task replacement, GUI-conflict refusal and
  disabled/inaccessible task handling without changing real settings.
- Repository checks validate exports, compatibility shims, deployment sources,
  ignored runtime data and high-confidence credential patterns. The credential
  scanner reports file/line locations only, not values. This is not a substitute
  for reviewing all content before publishing.
- Module command coverage must be **at least 90%**. Coverage of mocked command
  paths is not evidence that the corresponding Windows/native operation works.

Each shell writes `tests.nunit.xml`, `coverage.xml`, `parse-errors.txt` and
`script-analyzer.txt` under its own `out/test-results/pwsh/` or
`out/test-results/powershell/` directory. An empty diagnostics file indicates
zero findings for that check.

## CI boundary

Pushes, pull requests and manual dispatch run both `windows-latest` matrix jobs
with read-only repository permissions. Each job runs the Python and documentation
gates and bootstraps dependencies with `pwsh` before running Pester in its
selected shell. The upload step collects that shell's diagnostics, including
on a failed job, with a 14-day retention period. Inspect `test-results-powershell`
and `test-results-pwsh` on the run for the published commit. [Workflow](../.github/workflows/ci.yml)

## Scope of recorded results

Historical Unit/Integration passes do not establish coverage of subsequently
added standalone S001, MWB or migration-audit helpers. Review actual test results
and implementation scope before claiming full repository acceptance. For a
documentation-only pass, validate links, referenced paths and command parameters;
do not install dependencies, execute repair scripts or run live tests merely
to check prose.

## What still requires explicit live validation

- Task principals, desktop/session behavior, GUI exit confirmations and actual
  headless windows after a separate deployment.
- Network switching, independent rollback, proxy reachability, vendor licensing,
  and reboot/logon behavior.
- Actual WinINET notification, native process scheduling, audio/Bluetooth and
  saved Wi-Fi profiles.

Keep these outside default CI. Use the [safe operations runbook](safe-operations.md)
and [deployment migration](deployment-migration.md); never run an archived
`Test-*` script merely because its filename resembles a unit test.

## Continuous delivery boundary

This repository has no automatic deployment workflow or hosted deployment target.
CI validates source and publishes test diagnostics only; it does not deploy to
ERAZER, modify scheduled tasks, change network settings, or start SQX. Deployment
remains a separate, deliberate operation under the deployment runbook. A green
CI run does not certify live hardware, credentials, licensing, or service health.

Local checks require Git on the test process PATH as well as the selected
PowerShell executable. A portable Git copy can be added to that process PATH
without changing machine or user settings. Pinned modules stay under ignored
`out/dependencies/`; the checks do not install global modules.

PowerShell files containing non-ASCII text use UTF-8 with a BOM so Windows
PowerShell 5.1 parses them consistently on different Windows code pages. Keep
this marker when editing those files. If a WSL-launched Windows test process
cannot resolve `git` despite a valid PATH, verify that its `PATHEXT` includes
`.EXE`; repair only that test process environment before rerunning.

## Documentation checks and exclusions

To exercise examples offline, run the [setup simulation](../README.md#local-environment-no-docker-required)
and [status parser example](releases/1.0.2.md#check-a-status-reply-offline).
Review live SSH, task, GUI and repair commands against their source signatures
and prerequisites during a documentation pass.

The Markdown checker includes tracked and nonignored new Markdown in its source
checkout. Four frozen snapshots under docs/history retain old-layout links and
are explicitly excluded; the history index and current guides are checked.
The checker understands current inline links and ATX heading anchors, not every
Markdown extension, external URL availability or ignored/private evidence.
CLI annotations check named parameters, not all values, defaults or shell
quoting. Source review remains required. See the [audit](documentation-audit.md)
for the exact inventory and limitations.

Read the [release notes](releases/1.0.2.md) for the current module changes.
Check workflow results and artifacts at the exact commit referenced by a release.
