# SQX monitoring procedure

The documented October deployment was GUI145 on ERAZER. Verify the actual mode and read the dated
[current handoff](s001-current-handoff.md) before each new operator session.
Times in reports are Asia/Shanghai; native log filenames may encode UTC.

## Prerequisites

Use the configured pinned SSH identity and exact hostname verification. The
maintained transport is `scripts/remote/erazer_transport.py`; the compatibility
wrapper `out/s001-preservation/remote-hotspot.py` and authenticated monitor below
are retained local artifacts, absent from a clean checkout. Their evidence and
private configuration must be available before reuse. Never substitute unpinned
SSH or disable GUI authentication to work around missing configuration.

The GUI helper reads `SQX_GUI_REMOTE_PASSWORD` from ignored
`credentials.local.txt` privately. Do not print this file, the password, token,
or credential-bearing request bodies. API requests are sequential.

## One check, in order

1. Verify pinned host identity and record timestamp/route. Use bounded discovery
   if the primary route fails; consult the connection runbook before changing
   anything. A failed probe leaves engine state unknown.
2. Run the read-only monitor below. Confirm a valid JSON result before using it.
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

Example from the repository root in WSL; choose a **new** timestamp per check:

```bash
python3 out/sqx-monitor/gui-auth-query.py < out/sqx-monitor/monitor-gui.ps1 > out/sqx-monitor/YYYYMMDD-HHMM-current.json
python3 -m json.tool out/sqx-monitor/YYYYMMDD-HHMM-current.json > /dev/null
```

This invokes read-only GUI queries through pinned transport. An empty/invalid
output is a failed check, not zero counts. Preserve a separate connection or
query failure record; do not overwrite the last valid baseline. Do not replay
mutations after a timeout. If the helper is missing, restore/review it before
use rather than inventing an equivalent authenticated command on the fly.

## Telemetry and interpretation

| Field | Source / interpretation |
| --- | --- |
| Current project/task | Native GUI project list and current task log |
| Generated / Accepted | `GET /engine/loadVisualLog?projectName=S001_reproduce_project&type=global`, task stats |
| Counter timestamp | `NativeStatsAt`; record task/iteration/log segment with it |
| Native bank records | `NativeBankMetadata`; compare relevant builders and A00 |
| Saved records | On-disk `.sqx` enumeration under the verified current bank suffix |
| CPU | CPU-time delta divided by measured sample seconds and logical processors; capture delta immediately after sample |
| RAM / paging | Working set, available MB, page inputs/outputs per second; a single sample is not sustained health proof |
| Data activity | Engine-start-filtered downloader log events and native `DMDataProgresses` websocket observations |
| Errors | Timestamped relevant log entries; distinguish previous startup errors and diagnostic probe errors |

GUI port8080 is the current authenticated API. GUI port5050 may answer
`CLI not ready`; this does not mean S001 stopped. Historical headless CLI/CSV
commands and `sqx145-task1-start.txt` are not current GUI telemetry. If operating
an explicitly verified headless deployment later, validate its actual CSV schema
and response before extracting fields; do not mix modes.

The native websocket observer is `out/sqx-monitor/observe-native-streams.cjs`.
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

Save under `out/sqx-monitor/` with unique `YYYYMMDD-HHMM` prefixes:
`current.json`, `comparison.json`, `new-backup.json`, and failure/network evidence
when applicable. Save `out/s001-data-repair/YYYYMMDD-HHMM-progress.json` even if
its conclusion is current queue unknown and prior endpoint audit unchanged.

A report contains timestamp, connectivity, engine/task identity, bank counts and
deltas, candidate/retest totals and measured rates, retention/backup outcome,
CPU/RAM/paging, relevant errors, data progress and ETA limitations. The latest
user preference is to notify when Builder 2 completes or anything needs attention;
retain routine evidence without repeatedly alerting on an unchanged known issue.

The earlier operator policy requested keeping its hourly monitor active; this
repository neither creates nor verifies that schedule. Consult its current owner
before changing it. Do not mark the overall work complete
at Builder 2 completion: the handoff lists final export, preservation, historical
repair, data and isolated plugin acceptance gates. Schedule updates must retain
all pending work and consumed-authorization boundaries.
