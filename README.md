# ERAZER Remote Control

Operate **ERAZER-6JMHAKCD** from **STUPICVICPC** using pinned-key SSH, RustDesk,
StrategyQuant X 145 and Mouse Without Borders. Start with the
[documentation index](docs/README.md).

## Common work

| Need | Runbook |
| --- | --- |
| Connect or recover access | [Connections and proxy](docs/gateway-compatibility.md) |
| Continue S001 safely | [Current handoff](docs/s001-current-handoff.md) and [operations history](docs/s001-operations.md) |
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

Published module: **1.0.1**. Documentation reviewed **2026-11-07** against the
published source. This date does not refresh remote health, addresses or S001
state. Operational snapshots have their own timestamps and private prerequisites;
current counts belong in monitoring evidence, not installation instructions.

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

Use Git on Windows to clone this repository, then open its root in PowerShell.
PowerShell 7 is required for the supplied wrappers/test bootstrap; Windows
PowerShell 5.1 is also verified. Python 3 is needed for the documentation gate
and standalone helpers, with no pip dependencies.

```powershell
git clone https://github.com/victor000000/ERAZER_remote_control.git
Set-Location ERAZER_remote_control
```

A source clone does not install SQX, RustDesk, MWB, SSH identities or tasks. Use
the offline configuration-load example below before preparing private access.

## First read-only check

From the Windows controller, with the existing SSH identity configured:

```powershell
ssh erazer-hotspot hostname
```

A fresh checkout does not include private SSH keys, host overlays or ignored
monitoring helpers. For an offline first step, use the configuration-load example
below. For actual remote access follow the [connection runbook](docs/gateway-compatibility.md).
SQX status commands run on the SQX host; loopback on the controller is not the
target. CLI and authenticated GUI monitoring are separate interfaces.

## Configuration and deployment

### Local environment (no Docker required)

Run this toolkit directly on Windows. Docker Desktop, containers and Docker
Compose are not project dependencies; there is no container environment to
start or migrate. Windows PowerShell 5.1 is the operational runtime, and
PowerShell 7 is also used for development and verification. Windows APIs,
Task Scheduler and installed applications are accessed on their Windows host.

From a Windows PowerShell session at the repository root, load the module and
read the default configuration without deploying or starting applications:

```powershell
.\scripts\Initialize-Toolkit.ps1
```

For development, follow [Testing](docs/testing.md) to save the pinned test
dependencies locally and run the offline checks. The standalone Python helpers
use Python 3 and its standard library; they require no pip packages. WSL is
optional for controller-side file work and Python helpers. Run Windows-specific
operations and acceptance checks with Windows PowerShell on the intended host.
GitHub CI likewise uses Windows runners directly.

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

[Release 1.0.1](docs/releases/1.0.1.md) records the task-state safeguards.
The [documentation audit](docs/documentation-audit.md) inventories published
and native-only records, validation scope and remaining limits. Published docs
are not a substitute for the current authorized operator ledger. There is no
automatic deployment or requirement for Docker.
