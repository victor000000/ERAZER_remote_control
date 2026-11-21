# ERAZER Remote Control

This Windows toolkit operates a separate StrategyQuant X host from a controller.
It provides PowerShell commands for inspecting SQX, managing scheduled tasks
and applying network-specific proxy settings. Start with the
[offline setup](#local-environment-no-docker-required) or the [runbooks](docs/README.md).

## Common work

| Need | Runbook |
| --- | --- |
| Connect or recover access | [Connections and proxy](docs/gateway-compatibility.md) |
| Continue S001 safely | [Identify the active engine](docs/sqx-monitoring.md#choose-the-monitor), then consult the operator's current handoff and [recovery procedure](docs/troubleshooting.md#recover-after-a-headless-start-times-out) |
| Back up new strategies or repair historical files | [Preservation](docs/s001-preservation.md) |
| Report generation, historical-data progress and ETA | [SQX monitoring](docs/sqx-monitoring.md) |
| Repair shared mouse/keyboard and automatic reconnect | [Mouse Without Borders](docs/mouse-without-borders.md) |
| Review SQX 144 assets for 145 | [Asset migration](docs/sqx-asset-migration.md) |
| Change a deployment or lifecycle safely | [Safe operations](docs/safe-operations.md) and [deployment](docs/deployment-migration.md) |
| Understand the implemented design and file contracts | [Architecture](docs/architecture.md) |
| Configure or inspect command interfaces | [Configuration](docs/configuration.md) and [command reference](docs/command-reference.md) |
| Diagnose a failed check or operation | [Troubleshooting](docs/troubleshooting.md) |
| Develop or validate source | [Testing](docs/testing.md) |
| Find unresolved work | [Pending checks](CLEANUP-TODO.md) |

Module version **1.0.2**. The [documentation audit](docs/documentation-audit.md)
covers the 2026-11-07 source review. Use current monitoring evidence for remote
health, addresses and S001 state before operational changes.

## Repository layout

| Path | Role |
| --- | --- |
| `src/ERAZER.RemoteControl/` | Shared PowerShell module |
| `scripts/` | Maintained operation helpers; S001 helpers are in `scripts/sqx/s001/` |
| `config/` | Source defaults, explicit override example and bundle manifest |
| `tools/` | Compatibility shims requiring the complete bundle |
| `build/`, `tests/` | Offline checks and fixture-based tests |
| `docs/` | Current runbooks; `docs/history/` holds dated evidence |
| `archive/2026-10/` | Unsupported old scripts, including destructive actions; do not execute |
| `out/` | Ignored snapshots, audit reports and private operation evidence |

## Obtain the source

Clone the publication repository with Git and run the examples from its root.

```powershell
git clone https://github.com/victor000000/ERAZER_remote_control.git
Set-Location ERAZER_remote_control
```

## Configuration and deployment

### Local environment (no Docker required)

The module runs on Windows PowerShell 5.1 and PowerShell 7. From either shell,
load the shipped defaults and simulate a network outside the configured proxy map.

```powershell
$config = .\scripts\Initialize-Toolkit.ps1
$config.SchemaVersion
(.\scripts\network\Sync-ProxyWithNetwork.ps1 -DryRun -SimulateSsid 'unconfigured-example').Action
```

Expected output is `1` followed by `Disable`. The simulation reads configuration
and returns a decision. You can run it offline in a fresh clone.

For the test matrix, put Git and Python 3 on the test process's PATH and install
both PowerShell editions. The initial dependency download uses PowerShell 7,
PowerShellGet and an existing NuGet provider. See [testing and CI](docs/testing.md).
The SQX command wrappers also use `pwsh.exe`. Their installation paths and
fixed arguments are documented in [deployment and compatibility](docs/deployment-migration.md#compatibility-mapping).

For live access, provision the controller's Windows OpenSSH client, private
identity and pinned host-key record separately. Verify the target through the
[connection runbook](docs/gateway-compatibility.md). Run SQX status commands on
the verified target with the matching install, project and API configuration.

See [Docker cleanup](docs/docker-cleanup.md) for the boundary between this
project's native environment and Docker data owned by other local projects.

### Configuration and activation

The generic scripts listed in the [command reference](docs/command-reference.md) support `-ConfigPath` and explicit `-LocalConfigPath`;
a local file is never loaded automatically. Keep private overlays in ignored
`out/`. Never put passwords, keys or license material in tracked files.

Source changes and bundle staging do not deploy themselves. The original
restructure was source-only; later **S001 and MWB deployments are documented in
their own runbooks**. The historical fresh-run S001 workflow has a preserving launcher, whose
action differs from the generic toolkit starter. Do not replace it to satisfy
a generic task-action check. The bundle manifest does not include every
standalone helper or report; review [deployment scope](docs/deployment-migration.md).

Prefer silent, headless Windows commands. Preserve all strategies, saved Wi-Fi
profiles and the current engine. Never run a second SQX instance, force-kill it,
edit a live `.cfx`, or reinstall controller Tailscale as a fallback.

## Releases and documentation scope

[Release 1.0.2](docs/releases/1.0.2.md) covers CLI readiness and the
[source publication procedure](docs/releases/1.0.2.md#verify-and-publish).
[Release 1.0.1](docs/releases/1.0.1.md) records the task-state safeguards.
The [documentation audit](docs/documentation-audit.md) inventories published
and native-only records, validation scope and remaining limits. Published docs
are not a substitute for the current authorized operator ledger. There is no
automatic deployment or requirement for Docker.
