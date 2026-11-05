# Testing and CI

## Reproduce the checks

Use the native Windows environment described in the
[local setup](../README.md#local-environment-no-docker-required). Docker is not
required for development, tests or CI. Run from the repository root on Windows:

```powershell
pwsh -NoProfile -File .\build\Install-TestDependencies.ps1
pwsh -NoProfile -File .\build\Invoke-Checks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build\Invoke-Checks.ps1
```

The explicit bootstrap downloads Pester 5.7.1 and PSScriptAnalyzer 1.24.0 from
PowerShell Gallery into ignored `out/dependencies/`. It does not install modules
in user/system directories or change repository trust. The check command itself
is offline and fails clearly if the pinned dependencies are absent.

## What is checked

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

NUnit, JaCoCo coverage and parse/lint diagnostics are written separately under
`out/test-results/pwsh/` and `out/test-results/powershell/`.

## CI boundary

[The workflow](../.github/workflows/ci.yml) runs a Windows matrix with PowerShell
7 and Windows PowerShell 5.1, read-only repository permissions, timeouts and
artifact retention. It needs no production credentials, installed SQX, SSH,
RustDesk session, elevated token or ERAZER connection. It never executes the
historical cleanup/repair scripts. The workflow starts after this source is
pushed to a GitHub repository; local passing results are not a GitHub run.

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
