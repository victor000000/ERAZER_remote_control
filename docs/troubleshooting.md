# Troubleshooting and recovery boundaries

Use observations from the actual host and deployment mode. A source/test pass,
a router record or successful TCP connection is not proof of a healthy SQX run.
No troubleshooting command here authorizes a restart or destructive cleanup.

| Symptom | Read-only diagnosis | Next boundary |
| --- | --- | --- |
| Missing private overlay/SSH identity/local monitor | Check file existence without printing contents; review configuration and evidence portability | Restore private setup securely; do not commit it or disable identity/auth checks |
| SSH timeout or identity mismatch | Use bounded discovery and pinned hostname/key checks in the connection runbook | Engine state remains unknown; inspect before retrying a mutation |
| CLI says not ready but GUI exists | Verify intended install, process, ports and GUI mode | CLI and authenticated GUI monitoring differ; do not launch a second engine |
| Task query AccessDenied/QueryFailed | Inspect with the intended user/context | Not Missing; never recreate a task from incomplete inspection |
| Task state unknown/active/disabled | Read state, Enabled and actual action definition | Generic start requires Ready; registration cannot replace the reserved preserving task |
| Registered task action mismatch | Compare executable, exact arguments/config and working directory | Preserve dedicated S001 action; do not “fix” it with generic registration |
| Generic start blocked by GUI process | Confirm which engine owns the live project and saved state | Follow preserving/GUI workflow; no force-kill |
| Project stop or exit times out | Inspect native project/engine state and logs once connectivity returns | Request may have executed; no blind replay or force-stop |
| Proxy stays Hold | Inspect SSID, route, endpoint, failure/unknown counters and probe outcome | DryRun simulation tests policy, not real connectivity; target-side vendor checks are separate |
| MT5 update refused | Confirm running terminal and conflicting UpdateMT5/SkipMT5 flags | Do not restart a terminal as a proxy side effect |
| Archive comparison fails | Check expected transformed archive and complete entry-byte mismatch report | Source/output remain separate; preserve existing output and inspect offline |
| Managed bundle marker missing | Inspect destination and manifest before staging | Force does not permit overwriting an unmanaged directory |
| Test command cannot find Git | Check process PATH and PATHEXT includes `.EXE` | Repair the test process only; no machine-wide environment change needed |
| Dependency bootstrap fails | Read the pinned module/version and network/package-provider error | Bootstrap with PowerShell 7; it deliberately avoids installing a global NuGet provider |
| CI green, live feature still unverified | Compare CI scope with the exact operation/host | Tests do not certify licensing, principal/session, native imports or restart behavior |

[Configuration](configuration.md), [command reference](command-reference.md),
[connections](gateway-compatibility.md), [monitoring](sqx-monitoring.md), and
[deployment](deployment-migration.md) give the corresponding procedures.

## Incident evidence

Keep a new private timestamped record: host/deployment identity, process/run/log
segment, command intent, task query category, observed response/error category,
source/copy hashes and rollback receipts as applicable. Do not publish passwords,
tokens, private endpoints or credential-bearing requests. A missing receipt,
missing baseline or changed identity is an evidence gap, not a successful check.

Counters and conditional ETA may only be compared within matching run/task/log
identities. Inspect downloader endpoints/catalog persistence before concluding
that a quiet stream means completion. Preserve names as well as counts. The
[preservation ledger](s001-preservation.md) defines what a verified backup means.

The project does not calculate strategy validity, investment returns or live
trading acceptance. Provider reachability, data coverage, vendor entitlement and
research/economic acceptance each need their own evidence and owner.
