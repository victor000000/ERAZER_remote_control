# Command reference

Run from the repository root in Windows PowerShell 5.1 or PowerShell 7 as
appropriate. Git and PowerShell 7 are needed for development checks/wrappers;
standalone Python helpers use Python 3's standard library. These are implemented
script interfaces for module 1.0.1, not a full SQX vendor API specification.

## Safe first steps

```powershell
$config = .\scripts\Initialize-Toolkit.ps1
$config.SchemaVersion
.\scripts\network\Sync-ProxyWithNetwork.ps1 -DryRun -SimulateSsid 'unconfigured-example'
```

The first example only loads configuration. The second uses synthetic network
input and returns a decision without querying or changing the real network.
Do not remove DryRun from simulated commands. A read-only remote identity check
uses the operator's privately configured alias: `ssh erazer-hotspot hostname`.
It requires private setup absent from a fresh checkout and is not an offline test.

## Entry points

The table describes effects; help/metadata inspection does not execute a script.
WhatIf previews supported mutations but can still perform validation or reads.

| Script | Key parameters | Behavior / boundary |
| --- | --- | --- |
| `Initialize-Toolkit.ps1` | ConfigPath, LocalConfigPath | Return validated merged hashtable and import shared commands |
| `sqx/Get-SqxStatus.ps1` | Project, AsJson, ConfigPath, LocalConfigPath | Query CLI status plus local process/log/bank observations; no mutation |
| `sqx/Control-Sqx.ps1` | Action, Project, Task, ConfigPath, LocalConfigPath | Dispatch status/list, project mutation, headless or GUI operations |
| `sqx/Register-SqxTask.ps1` | Task (1–999, default 1), Project, Force, common config | Register only a reviewed generic task on target; no automatic triggers; protected task refused |
| `sqx/Start-SqxProject.ps1` | Task (default 1), Project, ReadyTimeoutSec (120), common config | Start an existing Enabled/Ready task with matching execute/arguments/working directory; never silently register |
| `sqx/Start-SqxEngine.ps1` | Task, Project, common config | Scheduled-task payload; validate host, refuse duplicate engine and return native exit code |
| `sqx/Stop-SqxProject.ps1` | Project, StopEngine, ExitTimeoutSec (60), common config | Require project-stop confirmation; optional graceful engine exit needs local target/loopback |
| `sqx/Rebuild-SqxProject.ps1` | SourceProject, OutputProject, CompareProject, TaskFile, TemplateFile, Force | Offline archive rebuild with explicit migration paths; never edits source in place |
| `network/Sync-ProxyWithNetwork.ps1` | Watch, DryRun, SimulateSsid, SimulateGateway, SimulateProxyAvailable, UpdateMT5, SkipMT5, common config | Decision simulation or target proxy policy; default 30-second watch interval, 700-ms probe timeout |
| `system/Get-AutostartStatus.ps1` | ConfigPath, LocalConfigPath, AsJson | Read tasks and startup entries; inspect query errors before restoration |
| `system/Restore-MihomoAutostart.ps1` | ConfigPath, LocalConfigPath | Explicit controller restoration via configured registrar; reconcile stale expectations first |
| `Deploy-Toolkit.ps1` | DestinationPath, Force | Stage a full bundle to an absolute path outside checkout; not remote deployment |
| `sqx/Start-TradingApps.ps1` | Sqx, StartMT5, common config | Explicit GUI launcher; refuses a running CLI; MT5 requires opt-in |
| `remote/Connect-RustDesk.ps1` | Address, UseSavedPassword, Reconnect, CredentialPath, common config | Explicit desktop connection; private saved credentials are optional and must never be copied into docs |
| root `Connect-ERAZER.ps1` | ForceScan, ResolveOnly, UpdateTargetRecord, remaining Command | Controller discovery and pinned identity before SSH; record changes require explicit opt-in |

Paths except the last row are relative to `scripts/`. “Common config” means
ConfigPath and LocalConfigPath. SupportsShouldProcess scripts also expose
WhatIf/Confirm; the standalone MWB/repair scripts are exceptions, not previews.
The exact parameter contracts below are checked statically against source:

<!-- cli: scripts/Initialize-Toolkit.ps1 | ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Get-SqxStatus.ps1 | Project,AsJson,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Control-Sqx.ps1 | Action,Project,Task,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Register-SqxTask.ps1 | Task,Project,Force,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Start-SqxProject.ps1 | Task,Project,ReadyTimeoutSec,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Start-SqxEngine.ps1 | Task,Project,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Stop-SqxProject.ps1 | Project,StopEngine,ExitTimeoutSec,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/sqx/Rebuild-SqxProject.ps1 | SourceProject,OutputProject,CompareProject,TaskFile,TemplateFile,Force -->
<!-- cli: scripts/network/Sync-ProxyWithNetwork.ps1 | Watch,DryRun,SimulateSsid,SimulateGateway,SimulateProxyAvailable,UpdateMT5,SkipMT5,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/system/Get-AutostartStatus.ps1 | ConfigPath,LocalConfigPath,AsJson -->
<!-- cli: scripts/system/Restore-MihomoAutostart.ps1 | ConfigPath,LocalConfigPath -->
<!-- cli: scripts/Deploy-Toolkit.ps1 | DestinationPath,Force -->
<!-- cli: scripts/sqx/Start-TradingApps.ps1 | Sqx,StartMT5,ConfigPath,LocalConfigPath -->
<!-- cli: scripts/remote/Connect-RustDesk.ps1 | Address,UseSavedPassword,Reconnect,CredentialPath,ConfigPath,LocalConfigPath -->
<!-- cli: Connect-ERAZER.ps1 | ForceScan,ResolveOnly,UpdateTargetRecord,Command -->

## CLI control actions

Control-Sqx accepts `status`, `list`, `start`, `stop`, `pause`, `resume`,
`start-task`, `start-from-task`, `exit`, `headless`, and `gui`.
Task numbers are one-based for task starts; passing zero fails for those actions.
`headless` defaults to task 1. `exit` requests project stop and engine exit;
`stop` only stops the project. `gui` refuses an existing CLI engine before
starting the configured GUI task. Preview a supported change with WhatIf;
review [safe operations](safe-operations.md) before actual lifecycle commands.

## Status result

`Get-SqxStatus.ps1 -AsJson` emits one object with `CheckedAt`, `Project`,
`EnginePresent`, `LastLoggedTask`, `Status`, `NasdaqDatabankSavedCount`,
`LatestSave`, and `Processes`. Nested Status contains Generated, AcceptedPercent,
RejectedPercent, Failed, GeneratedPerHour, AcceptedPerHour, ProjectDatabankCount
and Runtime. Processes contains Id, PriorityClass, WorkingSetMB and PrivateMB.

Missing bank/task/save observations are null; missing optional numeric status
fields are null and Runtime can be an empty string. EnginePresent only checks local sqcli,
not GUI engines. The saved-count lookup is specifically
`databank1_S001_use_nasdaq100`, even when another Project is selected. LastLoggedTask
comes from the latest matching project log, not a guaranteed current native task.
An invalid/not-ready CLI reply throws; it does not produce a fabricated zero
snapshot. Use the separate GUI [monitoring procedure](sqx-monitoring.md) when
that is the actual deployment mode.

## Specialized workflows

The [S001](s001-operations.md), [MWB](mouse-without-borders.md),
[network](gateway-compatibility.md) and [migration](sqx-asset-migration.md)
runbooks own specialized commands, their private prerequisites and recovery.
The migration scanner accepts `--source label=directory` repeatedly, `--target`
and `--output`; output creation is a local write, while input databases open
read-only. Use only offline copies and a new output directory for a review.
The Python SSH transport is an importable helper, not a standalone CLI; importing
it does not provision private SSH identities or a monitor.
