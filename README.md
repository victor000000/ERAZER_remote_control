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
| Develop or validate source | [Testing](docs/testing.md) |
| Find unresolved work | [Pending checks](CLEANUP-TODO.md) |

The latest documented verification is **2026-10-31, Asia/Shanghai**. HypoMux uses a configured static target address; MiFi addresses
require fresh discovery. Status snapshots and audit
artifacts stay in ignored `out/`; current counts belong in monitoring reports.

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

## First read-only check

From the Windows controller, with the existing SSH identity configured:

```powershell
ssh erazer-hotspot hostname
```

For a silent PowerShell check from this WSL workspace:

```bash
python3 out/s001-preservation/remote-hotspot.py <<'PS'
Get-Process -Name StrategyQuantX,sqcli -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,CPU,WorkingSet64
PS
```

That Python helper is a retained local artifact, not part of a clean checkout.
The [connection runbook](docs/gateway-compatibility.md) gives maintained
alternatives and address-discovery rules. Run SQX status scripts on ERAZER: loopback refers to the machine executing
the command. Current GUI monitoring uses authenticated port8080; GUI port5050
may return `CLI not ready`. Follow the monitoring runbook.

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

Generic toolkit scripts support `-ConfigPath` and explicit `-LocalConfigPath`;
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
