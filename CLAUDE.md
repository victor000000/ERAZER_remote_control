# ERAZER Remote Control — project instructions

Operate ERAZER-6JMHAKCD from STUPICVICPC. Read [README.md](README.md) and use the
[documentation index](docs/README.md) to select the relevant runbook.

## Operating rules

- Prefer silent, headless Windows PowerShell. Persistent remote work must use
  Task Scheduler; an SSH child can terminate when the session ends.
- Verify the current route using [connections](docs/gateway-compatibility.md).
  Known ERAZER addresses are hotspot `192.168.137.37` and LAN `192.168.1.198`.
  Keep strict SSH host-key checking and pinned `HostKeyAlias=100.105.143.1`.
  This numeric label is identity metadata, not a Tailscale transport.
- Controller Tailscale is removed by user request. Do not reinstall it or rely
  on overlay fallback. Keep saved Wi-Fi profiles. Network changes need a
  target-local rollback independent of the connection being changed.
- For S001, read [operations](docs/s001-operations.md) and
  [monitoring](docs/sqx-monitoring.md). Preserve every strategy, bank map and
  run. No second engine, force-kill, live `.cfx` edit or invented gate marker.
  The existing `SQX-Task1-Headless` task uses the preserving launcher; generic
  registration/start helpers must not replace it.
- MWB recovery is [documented separately](docs/mouse-without-borders.md).
  Its task may restart only MWB, never SQX or network adapters.
- Match proxy settings to the measured network and probe from ERAZER. Controller
  routing belongs to the Mihomo project; source defaults retaining OMR names
  are not current evidence. Do not restore obsolete transport automatically.
- Never display or commit license values, credentials, private SSH keys or
  passwords. Keep private overrides and raw evidence in ignored `out/`.
- Access denied is not missing. Inspect task/process/state before recovery;
  do not replace an inaccessible or active task based on incomplete inspection.

## Source and verification

Maintained source lives in `src/ERAZER.RemoteControl/` and `scripts/`.
`tools/` are compatibility shims requiring the complete bundle.
`archive/2026-10/` is unsupported historical code; never execute it for routine
operations or tests. [Deployment](docs/deployment-migration.md) is separate
from source edits and local staging. Local overrides require `-LocalConfigPath`.

Follow [testing](docs/testing.md) for pinned dependencies and offline checks in
PowerShell 7 and Windows PowerShell 5.1. Tests use fixtures/mocks, never live
registry, tasks, network or SQX operations. Do not install dependencies or
broaden tests unnecessarily for documentation-only changes.

Maintain concise runbooks with one owner per topic. Keep time-varying counts
in snapshots, dated evidence in history, and unresolved work in
[CLEANUP-TODO.md](CLEANUP-TODO.md). Existing user changes must be preserved.
