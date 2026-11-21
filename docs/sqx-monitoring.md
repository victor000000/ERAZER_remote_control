# SQX monitoring procedure

Identify the process, install, project and run from the operator's current
handoff and a fresh observation on the target. Record each sample with its time
zone. Native log filenames may use UTC.

## Choose the monitor

For a CLI run, the shipped [status script](../scripts/sqx/Get-SqxStatus.ps1)
queries the configured API and inspects processes, logs and one named bank on
the machine executing the script. Run it on the verified SQX host. Pass the
reviewed `-LocalConfigPath` when the install, project or API differs from the
defaults. `-AsJson` returns the fields in the [command reference](command-reference.md#status-result).
The saved count covers only the bank named there. Compare a new sample with a
matching run and log segment to establish progress.

For a GUI run, use the deployment's authenticated GUI observer. The October
[handoff](s001-current-handoff.md) describes a historical GUI installation.
A fresh source clone supplies the transport and the CLI script. Obtain the
GUI observer and its credentials from the operator's protected setup.

## Prerequisites

Use the configured pinned SSH identity and verify the returned hostname.
The [controller transport](../scripts/remote/erazer_transport.py) resolves the
target for an operator with working private SSH configuration. Its callers
supply the command and interpret its result.

The GUI helper reads its credentials locally. Run API requests sequentially
and keep credential-bearing requests and raw responses in the private workspace.

## One check, in order

1. Verify pinned host identity and record timestamp/route. Use bounded discovery
   if the primary route fails; consult the connection runbook before changing
   anything. A failed probe leaves engine state unknown.
2. Run the configured read-only observer. Confirm a valid JSON result before using it.
   Check actual PID, executable/install, project, bank suffix, task, iteration
   and log segment. Old values are comparison baselines, never assumptions.
3. Compare native counters only against a snapshot with all those identities
   matching. Save both baseline identity and measured elapsed time.
4. Compare native and disk bank counts, distinguish derived A00 records, then
   verify all prior names and preserve every newly accepted file as described
   in [preservation](s001-preservation.md).
5. Inspect current log errors, memory/paging and download observations. Separate
   startup/historical-file failures from active strategy-test failures.
6. Save comparison, receipt and data-progress records. Notify completion or
   attention-worthy issues; retain routine snapshots even when no alert is sent.

Give each observation a fresh private output path. Capture the observer's exit
code and diagnostics. Validate the JSON and match its identity fields before
using it as a baseline. Preserve a failed or partial observation separately.
If access times out after a start or stop request, inspect the existing run
before deciding whether another request is necessary.

## Telemetry and interpretation

| Field | Source / interpretation |
| --- | --- |
| Current project/task | Native GUI project list and current task log |
| Generated / Accepted | Native GUI project visual log for the verified project and task |
| Counter timestamp | `NativeStatsAt`; record task/iteration/log segment with it |
| Native bank records | `NativeBankMetadata`; compare relevant builders and A00 |
| Saved records | On-disk `.sqx` enumeration under the verified current bank suffix |
| CPU | CPU-time delta divided by measured sample seconds and logical processors; capture delta immediately after sample |
| RAM / paging | Working set, available MB, page inputs/outputs per second; a single sample is not sustained health proof |
| Data activity | Engine-start-filtered downloader log events and native `DMDataProgresses` websocket observations |
| Errors | Timestamped relevant log entries; distinguish previous startup errors and diagnostic probe errors |

Verify the API and port for the active engine. A GUI installation may answer
`CLI not ready` on the CLI port while its authenticated GUI observer reports
progress. The shipped headless status reader parses labeled text lines from
the CLI. A readiness timeout calls for [process and log checks](troubleshooting.md#recover-after-a-headless-start-times-out).

Use the operator's configured websocket observer for downloader events.
A quiet stream or no recent `Finished` log line does **not** establish queue 0.
Likewise `Finished` and 100% counters mean processed, not necessarily successful.
Validate persisted nonzero catalog histories/endpoints before closing data work.
Do not submit duplicate updates based on quiet logs or old RC1 queue counts.

## Rates and ETA

For matching task/iteration/segment snapshots:

```text
delta = current counter - previous counter
rate_per_hour = delta * 3600 / elapsed_seconds
conditional_hours = remaining saved slots / measured accepted_per_hour
```

Do not compute across restarts, counter resets, task changes or invalid snapshots.
Report generated and accepted rates separately. Check accepted changes against
saved new names; imports, derived copies and restorations are not acceptances.
A short sample or zero accepted delta does not support a reliable completion ETA.
Whole-pipeline ETA remains unknown until later task costs are measured. State
sample duration and uncertainty whenever a conditional estimate is useful.

## Evidence and reporting contract

Store the timestamp, connectivity, engine/task identity, bank changes, retest
totals, measured rates, backup checks, resource use and errors in the private
run ledger. Record unknown data progress or ETA explicitly. Follow the current
operator handoff for the reporting cadence and completion criteria, including
final export and preservation checks.
