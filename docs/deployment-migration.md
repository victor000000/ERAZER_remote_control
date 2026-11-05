# Deployment migration and compatibility

## Deployment boundary

This runbook owns generic toolkit staging and compatibility. The original
restructure was source-only; later preserving S001 and standalone MWB helpers
were deployed separately. See [S001 operations](s001-operations.md) and
[MWB](mouse-without-borders.md) for those actual deployments.

Source edits and local staging still do not migrate a running deployment.
Existing `SQX`/`Proxy` task actions may point to self-contained deployed helpers.
Inspect them before activation and preserve rollback copies.

**The generic task action is not the preserving S001 action.** Do not register
`Start-SqxEngine.ps1` over `SQX-Task1-Headless` to resolve a mismatch in a generic
starter. The current S001 run uses its reviewed preservation launcher.

`config/deployment.psd1` is an explicit file list: it includes the S001 helpers,
but currently excludes the standalone MWB helper and migration-audit scanner.
Their repository presence does not put them in a staged bundle. Update/review
the manifest only when deployment of those entries is actually intended.

## 1. Review configuration and offline checks

1. Review [`../config/defaults.psd1`](../config/defaults.psd1) and
   [`../config/local.example.psd1`](../config/local.example.psd1). Current SQX
   defaults use `C:\StrategyQuantX145`; historical documentation mentions 144.
   Select the actual host/install/project explicitly.
2. Use `-ConfigPath` for a base file and `-LocalConfigPath` for an explicitly
   requested local overlay. There is no implicit local override. Keep private
   configuration outside tracked source, for example in ignored
   `out/local.psd1`, and pass its path when operating the bundle. Never include
   credentials or license material in the deployment manifest.
3. If dependencies are not already installed, explicitly run
   [`../build/Install-TestDependencies.ps1`](../build/Install-TestDependencies.ps1)
   to install pinned **Pester 5.7.1** and **PSScriptAnalyzer 1.24.0**. This step
   can access PowerShell Gallery. Then run
   [`../build/Invoke-Checks.ps1`](../build/Invoke-Checks.ps1) for repository
   checks and offline tests. Passing them is not live deployment validation.

## 2. Preview and stage a complete local bundle

Review [`../config/deployment.psd1`](../config/deployment.psd1), then preview
with a new, explicit absolute local destination:

```powershell
pwsh -NoProfile -File .\scripts\Deploy-Toolkit.ps1 -DestinationPath C:\ToolkitStaging\ERAZER -WhatIf
```

After reviewing the destination, manifest and proposed changes, an operator can
run the same command without `-WhatIf` to stage the maintained bundle locally.
Use `-Force` only for an existing toolkit-marked bundle: staging refuses to
replace an unmanaged directory and retains a uniquely named backup of the old
managed bundle. Staging does not SSH, upload to ERAZER, register tasks or activate the
bundle; never point it at a live installation just to see what happens.

The maintained bundle must retain the relative layout of `src/`, `scripts/`,
`config/` and the supported `tools/` entries. A compatibility shim resolves its
canonical script from the repository/bundle root, and that script depends on
the module/configuration. **Copying a single `tools/*.ps1`, `.cmd` or `.vbs` to
the desktop is not supported.** The archive and private inventories are not a
maintained deployment source.

PowerShell 7 must be installed. The retained interactive `.cmd` wrappers use
`pwsh.exe` from PATH; the silent proxy `.vbs` launcher expects the standard
`%ProgramFiles%\PowerShell\7\pwsh.exe` installation. The proxy `.cmd`/`.vbs`
launcher uses fixed `-Watch -SkipMT5` defaults and returns before the watcher
finishes; its launch result is not a watcher-health check. Invoke the canonical
PowerShell script for custom configuration/options. No launcher creates a
persistent scheduled task automatically.

## 3. Approve live migration separately

Before transferring or activating anything:

1. Establish the independent access/rollback plan in
   [safe operations](safe-operations.md). Preserve old deployed files and export
   task definitions/actions, principals and triggers in an approved maintenance
   window. Do not read or package credentials.
2. Review and transfer the **complete** staged bundle to a separate versioned
   destination with an explicit operator-approved method. The staging command
   intentionally contains no SSH or task-registration automation.
3. Plan how the live task actions will pass explicit config paths and resolve
   the new complete bundle. Keep existing `SQX`/`Proxy` folders and old task
   definitions available for rollback. Do not remove fallback Wi-Fi profiles.
4. Review task registration explicitly. `Register-SqxTask.ps1` is for an
   on-demand headless task without automatic triggers. `Start-SqxEngine.ps1`
   is its payload, not a persistent SSH-child process. Do not add headless boot
   triggers or replace `StartTradingAppsAtLogon` as a side effect of migration.
5. Apply approved changes one at a time. Verify actual status, proxy reachability,
   graceful project stop/start, logging and GUI/headless separation. A preview
   cannot validate SQX licensing, desktop dialogs or a remote task principal.
6. Verify GUI-at-logon only during an approved logon/reboot test. Record what was
   actually tested and leave any untested item pending. If validation fails,
   restore the previous task actions/files/config and confirm recovery rather
   than force-killing SQX or deleting the previous deployment.

## Compatibility mapping

All original tools, including original versions of these names, are retained
under [`../archive/2026-10/tools/`](../archive/2026-10/tools/). The supported
`tools/` PowerShell files now only set terminating-error policy and forward
`@args` to these canonical paths relative to the repository root:

| Supported `tools/` name | Canonical maintained target | Fixed argument / role |
| --- | --- | --- |
| `Control-SQX.ps1` | [`scripts/sqx/Control-Sqx.ps1`](../scripts/sqx/Control-Sqx.ps1) | Explicit action |
| `Start-SQX145-Task1.ps1` | [`scripts/sqx/Start-SqxEngine.ps1`](../scripts/sqx/Start-SqxEngine.ps1) | `-Task 1`; scheduled-task payload; preserves native exit code |
| `Start-SQX145-Project.ps1` | [`scripts/sqx/Start-SqxEngine.ps1`](../scripts/sqx/Start-SqxEngine.ps1) | `-Task 2`; scheduled-task payload; preserves native exit code |
| `ERAZER-StartSQXTask1.ps1` | [`scripts/sqx/Start-SqxProject.ps1`](../scripts/sqx/Start-SqxProject.ps1) | `-Task 1`; starts the configured registered task |
| `Get-SQXStatus.ps1` | [`scripts/sqx/Get-SqxStatus.ps1`](../scripts/sqx/Get-SqxStatus.ps1) | Read status |
| `Stop-SQXProject.ps1` | [`scripts/sqx/Stop-SqxProject.ps1`](../scripts/sqx/Stop-SqxProject.ps1) | Project stop; optional explicit engine stop |
| `Sync-ProxyWithNetwork.ps1` | [`scripts/network/Sync-ProxyWithNetwork.ps1`](../scripts/network/Sync-ProxyWithNetwork.ps1) | MT5 updates require explicit opt-in |
| `Rebuild-SQXProject.ps1` | [`scripts/sqx/Rebuild-SqxProject.ps1`](../scripts/sqx/Rebuild-SqxProject.ps1) | Rebuild `.cfx`, never in-place edit |
| `Review-Autostart.ps1` | [`scripts/system/Get-AutostartStatus.ps1`](../scripts/system/Get-AutostartStatus.ps1) | Read-only inspection |
| `Verify-Autostart.ps1` | [`scripts/system/Get-AutostartStatus.ps1`](../scripts/system/Get-AutostartStatus.ps1) | Read-only inspection |
| `Check-MihomoAutostart.ps1` | [`scripts/system/Get-AutostartStatus.ps1`](../scripts/system/Get-AutostartStatus.ps1) | Read-only inspection |
| `Restore-MihomoAutostart.ps1` | [`scripts/system/Restore-MihomoAutostart.ps1`](../scripts/system/Restore-MihomoAutostart.ps1) | Explicit mutating operation |
| `Start-TradingApps.ps1` | [`scripts/sqx/Start-TradingApps.ps1`](../scripts/sqx/Start-TradingApps.ps1) | Explicit GUI launcher |

Only these four `.cmd` files remain supported in `tools/`:

- [`Control-SQX.cmd`](../tools/Control-SQX.cmd)
- [`Start-SQX145-Project.cmd`](../tools/Start-SQX145-Project.cmd)
- [`Start-TradingApps.cmd`](../tools/Start-TradingApps.cmd)
- [`Sync-ProxyWithNetwork.cmd`](../tools/Sync-ProxyWithNetwork.cmd), which uses
  [`Sync-ProxyWithNetwork.vbs`](../tools/Sync-ProxyWithNetwork.vbs) to launch its
  sibling PowerShell shim silently with `-Watch -SkipMT5`.

No other former `tools/` or root-script name has an implied supported
replacement. Root scripts other than
[`Connect-ERAZER.ps1`](../Connect-ERAZER.ps1) moved to
[`../archive/2026-10/root/`](../archive/2026-10/root/). Archive sibling layouts
are retained, but old absolute paths remain historical. Archived code can be
**destructive, is unsupported and is not covered operationally** by maintained
tests. Two archive parse-compatibility corrections are documented in the
[archive index](../archive/2026-10/README.md); neither script was executed.

## Historical documents and raw reports

The original README and review/checklist are preserved under
[`history/`](history/). Their literal paths/links refer to the pre-restructure
layout; use the history index and this mapping for current locations.

Raw `local-cleanup-log.txt`, `tools/windows-review.txt` and
`tools/local-network-review.txt` moved intact to local ignored `out/history/`
and were removed from tracking. No raw report or credential is needed for a
maintained deployment. See [`../CLEANUP-TODO.md`](../CLEANUP-TODO.md) for actual
pending verification, not historical completion claims.
