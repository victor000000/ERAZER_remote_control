# S001 operations

Applies to the preserving SQX 145 deployment on ERAZER. Use
[connections](gateway-compatibility.md) for access and
[monitoring](sqx-monitoring.md) for status, data-update logs and ETA.

## Current procedure and historical scope

Read [the current handoff](s001-current-handoff.md), [monitoring](sqx-monitoring.md)
and [preservation](s001-preservation.md) first. The sections below retain dated
implementation and incident details. Launch/start/restart commands are historical
recipes, **not commands to run against the current advancing GUI engine**.
Current configured caps are325/500/1000; Builder1 has finished325. PID4216 and
older headless processes below have been superseded by the Oct31 recovery.
Never replay a consumed one-time approval or a fresh-run launcher as resume.

## Historical recovery record

### October 30 handoff and controlled recovery

**Recovery completed:** the user separately approved terminating hung PID12348
when graceful exit failed. It was terminated only after backup verification;
the same GUI installation was launched once at 10:36:08 as **PID4216**, Xmx29g.
The exact unfinished Load task ran at 10:41:37 and finished all 325 copies in
11.836 seconds. Native live metadata confirms A00=325 and builders325/300/650,
project total1600. Builder2 generated **10 -> 22** candidates between 10:51:05
and 10:56:56 (123/hour), accepted0, bank300/500. This restart authorization is
consumed. Keep the advancing engine running; do not replay preparation or Load.

All67 project archive entries remain semantically identical before/after the
restart. The GUI heap limit is the only configuration change in this recovery.
RAM pressure remains severe despite a later zero-paging sample; no speedup or
memory-resolution claim. GUI startup automatically loaded historical projects,
which also autosync; do not manually load more historical banks. The user approved closing the orphan old interface group root12136. At
11:50 Oct30, its five verified October28 processes were terminated; current
engine4216 and new UI15304 remained running. The old group used3.67GB;
available RAM immediately increased to3897MB. This is a sampled improvement,
not proof of sustained memory recovery. The approval is consumed. Receipt:
`out/erazer-connection-recovery/20261030-approved-old-ui-closed.json`.


Builder 1 reached **325** at 08:12:31; its archive task saved all 325 at
08:14:24. The external script invocation produced no namespace copies and the
verified-marker guard correctly waited. Running the preserving helper through
a dedicated scheduled task created and verified all 325 copies, then released
the guard. The following native LoadFromFiles task stopped at 166 in-memory
copies with a GC-overhead memory error before Builder 2 started. Those are
derived copies of the preserved archive, not new accepted strategies.

All **1,275 builder files** (325/300/650) and **325 namespace copies** were
SHA-256 verified and backed up under
`C:\Users\Vic\ERAZER-Tools\Backups\S001-handoff-20261030`.
The final accepted Builder 1 file is `Strategy 0.3087.sqx`, SHA-256
`638ADC126A9C0AE80002516F376CFBEE89A393C51F7E7A0278CCD16B15841902`.
One native idle-engine memory cleanup found no other offheap cached data;
subsequent grid access still reported GC-overhead exhaustion. Do not repeat
cleanup or blindly retry the full load in this engine.

The user approved **one controlled restart** with more heap. The prepared
recovery script refuses to act while any engine or port8080 listener remains.
After confirmed exit it preserves the entire project and partial derived bank,
verifies the 1,275 builder hashes, changes only GUI Xmx24g to Xmx29g, and registers
the same GUI executable for one launch. The existing project/run is retained.
Start the exact unfinished `Load distinct B01 candidates into A00_NasdaqCandidates`
task once; require actual native 325 loaded records before Builder 2 advancement.
Never start Builder 1 again. Never launch a replacement while PID12348 remains.



### Current continuous-run recovery (2026-10-29)

Candidate telemetry is available through authenticated, read-only
`GET /engine/loadVisualLog?projectName=S001_reproduce_project&type=global`.
Its `tasks[].stats[]` supplies `Generated` and `Accepted` counts with a task
title and iteration. Compare timestamped snapshots only for the same task,
iteration and recovery segment. On Oct29 08:53 it reported 1,285 generated
and zero accepted: an unchanged accepted bank alone did not establish a stall.
The monitor now saves this response as `NativeTaskStats`; use its deltas rather
than CPU or the missing detailed WebSocket engine stream to verify generation.

The Oct29 acceptance audit found Build 1 byte-identical in the active and RC1
copies. Its enabled gates are trades/month >2, PF >1.3, drawdown <53%, similarity
rejection, and portfolio correlation <=0.7 against the existing builder bank.
Crosschecks are disabled in this build. These settings identify possible gates,
not measured rejection counts by gate. Do not relax them to manufacture progress.

`DownloadObservation` records current-engine log evidence separately from an
unknown pending count. The historical RC1 queue cannot be reused after an engine
switch. One native `data/resumeAll` at Oct29 10:59 acknowledged continuing existing
jobs but produced no observed progress; it did not submit a new update batch.
Do not repeat this action every hour or infer an empty queue from absent events.

The user reauthorized keeping S001 running and recovering safe stops at every
hourly check. Discover the listening engine's executable and project path each
time: installations can change independently of the monitor. The current GUI
uses authenticated port 8080; `out/sqx-monitor/gui-auth-query.py` reads the
Git-ignored `SQX_GUI_REMOTE_PASSWORD` credential without printing it.

On Oct29, the existing `C:\StrategyQuantX145` GUI PID12348 had loaded S001 but
had no active task. After backing up all 8,157 project files (matching file
sizes and project SHA-256), native `project/start` POST with
`projectName=S001_reproduce_project`, `action=runProjectFromHere`, and
`taskName=Build 1: S001 Nasdaq template (cap 500)` continued the existing run
at 04:53:31. Logs confirmed data prepared at 04:53:58 and generation starting
at 04:54:01. No engine restart or project/configuration replacement was needed.

For future checks, leave an active project running; distinguish paused from
stopped. Before recovering a stop, verify the unfinished task, run suffix and
bank preservation, then use the corresponding native action in the existing
engine. Never blindly return to Build 1 after downstream advancement or project
completion. Recheck logs and state after an HTTP timeout before any retry.
Report actual counter deltas when available; an active task or CPU sample alone
does not measure candidate throughput. Do not force-kill, launch a second
engine, reset the run, or edit a live archive to recover it.

The active copy retained 318/300/650 records. RC1 additionally contains
`Strategy 0.2876.sqx`, separately backed up and hash-verified under
`C:\Users\Vic\ERAZER-Tools\Backups\S001-engine-change-20261029-0039`.
It has not been merged into the active bank; preserve it for reconciliation.
The full recovery backup is
`C:\Users\Vic\ERAZER-Tools\Backups\S001-continue-20261029-0452\project`.
Historical instructions and caps below must be interpreted against the actual
current configuration and later user authorization.

- Inspect process/API/counter deltas before recovery; existence alone is not progress.
- Keep the current engine and run. The original historical builder caps were200/300/650; current caps are documented in the current handoff.
- Builder originals and downstream namespaced copies are separate retained records.
- Never replace the existing preserving task with the generic toolkit task action.
- If the engine has exited, inspect the last-run ledger, logs and archive state
  before starting the existing task. Starting can prepare a fresh run; it is not
  a generic resume command for a blocked live project.


These are the helpers saved from the S001 revision 2 deployment verified on
ERAZER on 2026-10-20. Source lives in `scripts/sqx/s001/`, outside ignored
temporary output. Saving or staging these files does not change the running
engine, deployed files, or scheduled tasks.

| Script | Purpose |
| --- | --- |
| `Build-S001Project.py` | Builds the reviewed 66-task / 42-bank blueprint, manifest, archive-folder list, and helper bundle offline. Uses Python 3 standard library only. |
| `Start-S001PreservingProject.ps1` | Scheduler payload: verifies the blueprint hash, backs up the current project and saved banks, prepares versioned banks, seeds build caches, atomically replaces the project archive, and starts SQX hidden. `-PrepareOnly` performs preparation without starting SQX. |
| `Namespace-SqxFiles.ps1` | Copies `.sqx` files with B01/B02/B03 prefixes and content-derived IDs. Verifies strategy definitions and binary result streams; refuses collisions and leaves originals intact. |
| `Start-S001ArchiveRun.ps1` | Creates dated export folders and rotates the `current` junction while retaining previous runs. Called by the launcher. |
| `Optimize-S001Memory.ps1` | Scheduled maintenance for the 32 GB ERAZER host while S001 is on its first build: backs up all project files, verifies strategy hashes, and restarts the same run with a 20 GB initial / 29 GB maximum G1 heap. Supports `-WhatIf`. |

## Historical headless launch procedure — not current GUI recovery

Run Windows commands headlessly and silently. Long-lived engine work must use
Task Scheduler, since an SSH session ending can terminate its child processes.
After checking that SQX has exited and the existing launcher is appropriate for
the intended run, use its on-demand task:

```powershell
Start-ScheduledTask -TaskName 'SQX-Task1-Headless'
```

Its existing `Start-SQX145-Task1.ps1` wrapper calls
`C:\Users\Vic\ERAZER-Tools\SQX\Start-S001PreservingProject.ps1`.
Do not substitute the generic project starter: direct GUI/API Start skips fresh
bank and archive preparation. Do not start another engine alongside a GUI or
CLI instance, force-kill SQX, or replace an active scheduled task.

## Memory profile on the 32 GB ERAZER host

The user-requested 29 GB trial profile uses `-Xms20g`, `-Xmx29g`, G1 GC,
`-XX:GCTimeRatio=99`, and the existing `-XX:+AlwaysPreTouch`. The ratio sets a
1% garbage-collection time target; it is a tuning goal, not a measured speed
guarantee. Keep the remaining physical RAM available for Java native memory,
Windows, file caching, SSH, and RustDesk. Actual usage can remain below the
maximum. Do not assign the entire 32 GB to the Java heap.

GC logs rotate under `C:\StrategyQuantX145\user\log\sqx-memory-<PID>.log`
(three 10 MB files per process). Retain the process-specific diagnostics in
`C:\Users\Vic\ERAZER-Tools\SQX\Memory-review-20261020` when evaluating changes.
The standard Java attach interface is unavailable in this SQX process;
`jstat` works when invoked by a scheduled task in the same interactive session
as SQX. SSH-session `jstat` can fail despite a healthy running JVM.

The current CLI profile keeps system proxies enabled but bypasses them for
`strategyquant.com` and its subdomains through `http.nonProxyHosts`. This
restored license verification when HypoMux's controller proxy timed out during
HTTPS negotiation and direct Java HTTPS worked. Keep the exception when
retuning memory. The maintenance helper tests license-site connectivity with
the same Java network properties before stopping SQX; `-WhatIf` does not run
this network probe.

`Optimize-S001Memory.ps1 -RunDirectory <dedicated-existing-folder> -MaximumHeapGB 29 -WhatIf`
checks the maintenance preconditions. Actual application must run headlessly
through Task Scheduler, with a separate recovery task. The helper accepts
only the first S001 build, backs up and verifies the complete saved project,
and uses the existing launcher's verified prepared-run path to retain the
same run ID and bank map. It rotates the dated archive link while retaining
previous archive folders. This is maintenance of an unfinished first build;
normal fresh runs still use the usual launcher preparation.

The maintenance folder is single-use. Before retrying a failed operation,
inspect `maintenance.log`, `maintenance-errors.txt`, the completion/recovery
markers, current process, and launcher state. Original JVM configuration and
the complete saved project are retained there for recovery.

The saved launcher is scoped to `ERAZER-6JMHAKCD`, installation
`C:\StrategyQuantX145`, and project `S001_reproduce_project`. It requires the
existing `C:\Users\Vic\ERAZER-Tools\Logs` directory and the three helpers plus
generated blueprint, manifest, and folder list together under
`C:\Users\Vic\ERAZER-Tools\SQX`. The `sqcli.exe` executable, existing scheduler
wrapper, and task registration are deployment prerequisites, not generated by
the builder. These helpers were verified with SQX 145.3191; revalidate native
task formats before use with another SQX version.

## Rebuild a reviewable bundle locally

The builder requires the exact original 21-task archive used for the review.
It checks SHA-256 before applying original task-number mappings and refuses an
existing output directory. It never reads or modifies the running project.

```bash
python3 scripts/sqx/s001/Build-S001Project.py \
  --source out/s001-preservation/original.cfx \
  --output-dir out/s001-bundle-review
```

The original source SHA-256 is
`5f0e6b21a62e3ef041e4163f2560ab99a64761636b1ded54335b58d7404bb9cc`.
Keep that local original and the remote backups. A current revised `project.cfx`
cannot substitute for the original. Strategy archives, blueprints, ledgers,
and generated bundles stay in ignored local storage or remote backups; they
are not source files to commit. The bundle has deterministic ZIP metadata;
its manifest records its own blueprint hash. Compare ZIP entry contents when
comparing it with the deployed blueprint, whose ZIP timestamps may differ.

Review the generated manifest and task XML before any deployment. The builder
keeps the original datasets, dates, strategy templates, filter thresholds,
risk settings, and crosschecks. It changes bank routing and preservation
settings. Generated artifacts belong together; do not mix a blueprint and a
manifest from different builds. `scripts/Deploy-Toolkit.ps1` can stage the
maintained source bundle locally, but does not install these helpers into the
live SQX directory or update tasks.

## Preservation rules and lessons

- Three separate builders retain caps **200 / 300 / 650** and stop when full.
- Raw accepted builder records go directly to the first retest. They do not
  carry the retest Passed marker; applying a Passed gate first would discard
  all raw candidates.
- Retests retain both pass and fail results in `_All`; only `_Passed` copies
  feed the next stage. Native validation confirmed `MaxStrategies=0` with
  `DeleteFailedStrategies=false` retains failures in SQX 145.
- Correlation filters operate on derived inputs. Complete retest results
  remain available separately and are archived before filtering.
- Historical results remain in prior bank folders and backups. Do not merge
  those histories into current validation inputs or delete them to reduce the
  visible bank count.
- Namespacing changes only `ResultsGroup/ResultName` in copied settings. It
  verifies other archive entries and preserves source files. A failed helper
  does not write the success marker, so the workflow cannot advance to loading
  unverified copies.
- All project archive changes use a separate validated ZIP and atomic
  replacement while SQX is stopped. Never edit the live ZIP in place.
- Native tests confirmed distinct same-name builder records survive merging,
  501 loaded records survive without a hidden 500 cap, failed strategies stay
  in `_All`, and failed strategies do not enter `_Passed`. These are historical
  validation results, not a reason to run test projects against a busy install.

## Logs and recovery

| Location on ERAZER | Contents |
| --- | --- |
| `C:\Users\Vic\ERAZER-Tools\Logs\S001-preservation-launch.log` | Preparation, verified backup, launch, and exit events |
| `C:\Users\Vic\ERAZER-Tools\Logs\sqx145-task1-start.txt` and `.err` | Engine stdout and stderr |
| `C:\Users\Vic\ERAZER-Tools\SQX\S001-preservation-last-run.json` | Current bank map, blueprint/project hashes, run ID, and pre-run backup path |
| `C:\Users\Vic\ERAZER-Tools\Backups\S001-runs\before-<run>` | Prior project, registered saved banks, previous ledger, and verified file hashes |
| `C:\Users\Vic\ERAZER-Tools\StrategyArchives\S001_reproduce_project` | Dated full result exports, `current` junction, and retained prior links |

Review evidence remains locally in
`out/s001-review-v2/completion-report.json`. Remote pre-review backups are in
`C:\Users\Vic\ERAZER-Tools\Backups\S001-review-v2-20261020` and the earlier
`C:\Users\Vic\ERAZER-Tools\Backups\S001-preserve-20261020`. All 956 saved
pre-review strategy files were verified unchanged at deployment; this counts
files, including cache copies, rather than unique strategies.

## Namespace gate recovery

At October 20 23:45 Shanghai, Builder 1 had reached cap 200 and exported 200
originals. Its conhost-launched namespace step produced no copies, so the
verification gate correctly blocked. Running the existing namespace helper
through a hidden scheduled task with the established interactive principal
verified 200 copies and wrote the real marker; S001 advanced to Builder 2.
This was a launcher failure, not a reason to bypass the preservation gate.

Evidence on ERAZER:

- `C:\Users\Vic\ERAZER-Tools\SQX\Recover-B01-20261020.ps1`
- `C:\Users\Vic\ERAZER-Tools\Logs\Recover-B01-20261020.log`

The one-off recovery script is historical evidence; do not rerun it blindly.
For a future B02/B03 gate:

1. Confirm the current task from logs and API; inspect helper processes and
   existing scheduled tasks before creating another action.
2. Confirm the source builder reached its own cap and the actual archive source
   contains the required complete strategy files. Resolve the current archive
   paths and matching destination; do not reuse B01 paths or prefix.
3. If the destination is empty, run the existing `Namespace-SqxFiles.ps1` directly
   with hidden `powershell.exe` through the established task principal, using
   the correct B02/B03 prefix, minimum count and source/destination parameters.
   Inspect the helper's actual parameters rather than copying an old command.
4. If the destination is partially populated, investigate first. Never delete,
   overwrite or manufacture `namespace.ok` to force advancement.
5. Require the helper's own content verification and marker, then verify actual
   task/counter advancement. Keep both originals and copies.

No force-kill, second engine or live project archive edit is part of recovery.

## Builder 2 review and verified release (2026-10-24)

The user requested a review after Builder 2 finishes, before downstream work.
Review completed; original helper restored with verified hash. All 300 B02 copies
passed normal verification; S001 resumed into the Dow retest at 06:45 Shanghai.
Do not rerun B02 release or reinstall the historical review hold.
See [review hold and release procedure](s001-builder2-review.md).

## B03 recovery verified 2026-10-24

Builder3 completed650 at11:21:20; conhost returned without copies. After verifying source650, empty destination, original helper hash and no helper process/task, hidden SQX-Release-B03-20261024 ran the existing helper. Exit0,650 verified copies, genuine marker; samePID14444 resumed11:43:36 into B1 S&P500 OOS/crosschecks. B00=653;35 OOS results at11:48 confirm advancement. Do not rerun recovery. Evidence `../out/sqx-monitor/20261024-1144-advancement.json`.

## Dow-aligned robustness rerun (2026-10-24)

User requested identical Dow settings matching the later task. Separate project `S001_Robustness_Rerun_20261024` started16:53:38, reusing500 B01/B02 candidates and650 preserved B03 candidates. Both Dow XMLs match except bank routing; no original builders regenerated. See `../out/s001-robustness-rerun/README.md`, `manifest.json`, and `monitor.ps1`. Final exports are provisional pending audit because the original final strategy logged a crosscheck exception despite stored Passed. Single authorized repair enginePID11548; do not start another engine. Monitor this rerun, not the completed original run. All15 missing histories populated throughOct22;885 further native refresh requests queued16:52, do not duplicate.

## Rerun outcome, A02 gate change and B10 abort (2026-10-25)

The rerun finished all 52 tasks except B10. B10 ran 23:36:03 to 00:05:54
(29 min 51 s) and was stopped by `OutOfMemoryError` (heap max 29 GB, working set
25.39 GB at 17:49, concurrent 885-symbol refresh). Only 7 of 15 candidates were
tested: 3 failed the main backtest and stored no optimization profile, and all 4
that reached the permutation check failed its **uniform distribution** criterion
(`UniformDistrChanges=5`). No candidate failed on profit level or stdev, and 8
were never tested; see `../out/s001-robustness-rerun/a02-b10-diagnosis.json`.

At the user's request the A02 `ProfitFactor` gate changed 1.3 to 1.2. SQX was
stopped gracefully first (`-exit` over loopback, no force-kill), the archive was
backed up to `C:\Users\Vic\ERAZER-Tools\Backups\S001-rerun-a02-pf12-20261025`,
and a validated archive was swapped in atomically (53 entries, only
`Retest-Task6.xml` changed). The engine is stopped; the next start loads PF 1.2.

B10 was then re-run to completion on the restarted engine (09:01:21 to 09:36:22,
35 min): all 15 candidates tested, 0 passed, 11 rejected by uniform distribution
and 4 by best Optimization profit, then archived (31 files) with an empty
B10_Passed. The earlier hang was a deadlock, not an OOM: all 263 threads in
`Wait`, zero CPU and I/O, loopback API unresponsive. The recovery terminated the
hung process and restarted from a settled project load.

At the user's request B08 `MonteCarloManipulation.NumberOfSimulations` changed
50 to 100 (B09 Monte Carlo retest was already 100; B10 has no Monte Carlo step).
Same procedure, backup at
`C:\Users\Vic\ERAZER-Tools\Backups\S001-rerun-b08sim100-20261025`; only
`AutomaticRetest-Task3.xml` changed. The engine is stopped; B08 has not been
re-run, so B09/B10 results predate this change.

## Next-run builder caps 500 / 500 / 1000 (offline preparation, 2026-10-25)

The caps are generated, not live settings: `Rankings/MaxStrategies` in the three
Build tasks, the namespace `-MinimumCount` values, and the task titles. The
generator now accepts `cap=` overrides and `Build-S001Project.py` builds
500 / 500 / 1000. Rebuilt to `out/s001-bundle-caps-500-500-1000-v2`; against the
deployed blueprint only the three Build tasks, their three
`CallExternalScript` namespace entries and `config.xml` titles differ, the
37-bank map and 66-task order are identical, and every entry parses.

The generator carried a latent typo, `WindowsPowerShell<VT>1.0`, which the
2026-10-24 launcher repair had fixed only in the deployed archive. Rebuilding
from the unrepaired generator reintroduced the invalid XML character; it is now
`WindowsPowerShell\v1.0\powershell.exe` in source. Do not deploy that earlier
`out/s001-bundle-caps-500-500-1000` directory.

Deployment is not performed: it needs the blueprint and manifest copied together
(hash pair) with the previous pair backed up, then the existing
`SQX-Task1-Headless` launcher. The launcher seeds each builder bank from the
prior run, so the new caps build only the delta and no databank is deleted.

## Permanent namespace launcher repair (2026-10-24 18:04 Shanghai)

The maintained generator and deployed future-run blueprint now invoke
`powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File`
directly, removing the failed conhost intermediary. Exactly the three namespace
CallExternalScript entries changed in the deployed blueprint; all other entries
were verified byte-identical. The original Namespace-SqxFiles.ps1 hash, minimum
counts and separate marker gates remain intact. The blueprint manifest hash was
updated, with both previous files backed up under
`C:\Users\Vic\ERAZER-Tools\SQX\LauncherRepair-20261024-180435`.

An isolated archived strategy copy passed the actual hidden PowerShell command
(exit 0, real verification marker, original hash unchanged). This verifies the
command/helper path; a complete future SQX namespace gate remains an integration
check. No running project archive or bank was changed, and no completed run was
restarted. The active robustness rerun has no namespace launch steps. Evidence:
`../out/s001-launcher-repair/verification.json`.

## Same-run continuation verified 2026-10-25 17:55 Shanghai

User explicitly requested debugging and continuous operation after the 14:16 API
stop. `action=resume` acknowledged success but did not restart a stopped project.
Backed up project and all 7,744 on-disk strategy files under
`C:\Users\Vic\ERAZER-Tools\Backups\S001-continue-20261025-175302`; verified hashes
of all 1,168 current-run records. Existing-engine `action=startFromTask task=1`
started Builder 1 at 17:53:57, retaining run suffix 20261025095236452 and banks
218/500, 300/500, 650/1000. HTTP timed out, but logs and 23 new candidates at
17:55:29 verified success in PID 26040. Never repeat a timed-out action without
checking actual state. Generation counters reset on continuation; 8,425 earlier
candidates are historical. The first completed candidates took about 90 seconds.

Avoid loading historical project banks while building: earlier partial memory
loads were followed by autosync removing unloaded files. Historical rerun B00/B01
reconciliation remains outstanding; inspect archived files without loading them
into the live engine. Do not treat archive filename coverage as byte identity.

## Repeated API stop investigation (2026-10-25 18:36 Shanghai)

Explicit stop commands at 18:02:42 and 18:11:17 are confirmed in the engine log;
the sender is not yet identified. Scheduled SQX task run times do not match those
stops. PowerShell launch/script logs did not attribute them. The formerly present
SSH PowerShell session PID17668 ended, but there is no evidence sufficient to
attribute the stops to it. Do not disable unrelated scripts or blame that session.

User requested fixing the source and continuous operation. Same engine PID26040,
same run/banks continued from task1 at18:30:35;18:35:45 verified122 candidates and
1169records (Builder1=219). No settings or strategies were deleted/replaced.
A bounded 30-minute read-only observer, scheduled task SQX-API-Observer-20261025,
records port5050 client PID/parent/script paths and stop-event times to
C:\Users\Vic\ERAZER-Tools\Logs\S001-stop-trace\clients.jsonl and stops.jsonl.
It never issues API commands. Source: out/sqx-monitor/Trace-SqxApiClients.ps1.
Remove its scheduled-task registration after collecting evidence; it self-exits.
Short pktmon capture found no attributable request; pktmon is stopped and its
S001-API filter removed. Capture files remain in the trace directory.
This is diagnostic coverage, not a confirmed fix of the unknown stop sender.


## Native rejection and targeted data recovery verified 2026-10-29

LATEST VERIFIED Oct29 11:40 Shanghai: S001 remains in existing PID12348 C:/StrategyQuantX145, same recovery segment04:53:31, Build1 iteration1. At11:35 Native Generated2130 Accepted2; saved banks320/300/650 total1270 (+2 current recovery). CPU67.8%,WS19.17GB available7058MB paging0sample. Two new accepted files Strategy0.1480 and Strategy0.2049 separately backed up and SHA256verified at C:/Users/Vic/ERAZER-Tools/Backups/S001-new-acceptances-20261029-1135. RC1extra0.2876 still separately preserved; no merge performed. No acceptance setting, cost, formula, run reset or engine restart occurred.
DOMINANT REJECTION GATE PROVEN via native engine UI/WebSocket at11:14: Generated2024,Accepted1,Rejected2023; native dismissalStats Correlation with existing portfolio2019=99.8%, PF>1.30 only4=0.2%. Native logs show both >0.70 correlation and negative correlation rejected (even -0.01 because allowNegative=false). Visible memory-capped log sample is not whole-run subtype breakdown. Do not change these settings; Build-Task2.xml hash matches reference9c833032e63971c2e1d451ddc89dff81c074704bd28fdf30413dc1e1ac77fb32. Evidence out/sqx-monitor/20261029-rejection-breakdown.json and20261029-dominant-gate-summary.json. Native loadVisualLog remains reliable Generated/Accepted hourly source. Detailed dismissalStats can be captured by read-only inspect-dashboard.cjs on native S001 Engine view; no historical bank loads.
DATA RECOVERY VERIFIED: six native targeted update requests issued ONCE for ABBV.D11:04, AXON.D11:14, NSC.D11:16, PETS.D/ANIX.D/MEI.D11:18. All six Finished by11:32:56, last dispatcher alreadyexecuted0/inqueue0. Fresh readonly copied current-install SQLite at11:39 shows all six NONZERO endpoints advanced Oct21->Oct27, each +4 rows. Earlier post-Finished stale catalog snapshots lagged persisted advancement; they are superseded and are NOT continuing provider blockers. Original885 refresh scope now885/885 nonzero at or afterOct22 target. Do NOT requeue these six or replay historical RC1queue3877/12706bulk. Evidence out/s001-data-repair/20261029-six-completed-endpoint-audit.json,20261029-original885-recovered-audit.json. This meets original Oct24refresh target, not proof all current symbols have latest tradingday, running caches refreshed, or @ES/COFUSUSD separate failures fixed.
DOWNLOAD TELEMETRY FIX: native queue lives in WebSocket DMDataProgresses push, not main/getData(catalog) or headlessCLI. Tested observer out/sqx-monitor/observe-native-streams.cjs uses bundled WindowsNode/playwrightutilsBundle.ws and SQUANT+TASKMANAGER+SQMANAGER setup, Origin/UserAgent, project subscriptions. Captured4/6 ANIX/MEIPreparing11:31; all6laterFinished and endpoints verified. Quiet stream is NOT livequeue0. Preserve timestamped native progress/dispatcher observations, avoid claiming enumeration unavailable means queue stalled. Local pinned SSH tunnel18080 exists, localPID23424, controller C:/Windows/System32/OpenSSH/ssh.exe, forwards ERAZER8080 direct192.168.137.37 with pinned HostKeyAlias100.105.143.1; reuse only after verify, never launch duplicate. Reusable browser inspector is now read-only; one-time NSCmutation removed.
Continue hourly visible status, safe verified stopped/paused recovery within existing engine, no healthy-run restart. Preserve all pending final run/export/preservation audits and authorized plugin followup. Native update batch is finished; plugin tests still wait S001 completion and required final audits. Historical preservation discrepancies and non-S001 provider failures remain explicit pending work. Mihomo authorized chat informed successful recovery; no routing/socket changes needed for this batch.


## Correlation coefficient audit and diagnostic OOM recovery — 2026-10-29

LATEST CORRELATION AUDIT AND INCIDENT RECOVERY Oct29 16:29 Shanghai: PID12348 in C:/StrategyQuantX145 remains the sole GUI engine. S001 Build1 resumed after a diagnostic-caused OOM at16:05:17.027, same bankrun20261025095236452. NEW recovery log global_log_20261029_080517.log supersedes old04:53segment. At16:29 NativeGenerated83/Accepted0 since NEW segment; priorsegment3523Generated/4Accepted is HISTORICAL. 16:09Generated15 ->16:18Generated44 ->16:24Generated66 ->16:29Generated83 proves completed-candidate advancement. Builderbanks322/300/650 total1272, four accepted additions retained (0.1480,0.2049,0.2359,0.3265). At16:29CPU59.6%,WS18.94GB available7966MB paging0sample. No engine restart/secondengine/acceptance change.
CORRELATION VALUES VERIFIED: out/sqx-correlation-debug/verified-correlation-comparison.json and correlation-comparison.csv contain21 independently recomputed saved-pair Pearson values, ALL match native SQX matrix at displayed2dp. Daily realized P/L by close date, fullsample127/bothdirections0, ProfitLoss/Day10/addEmptyPeriods=false. Examples: B01 0.10792 vs0.1480 raw0.547064621->SQX0.55; vs0.2049 raw0.610367684->0.61; B01 0.1057 vs0.2359 raw0.003185513->0.00; B01 0.1350 vs0.2049 raw0.004621070->0.00. Differences are rounding at displayedprecision; CSV money rounds to cents. This does NOT prove fullprecision identity or every rejected coefficient. All saved sample pairs nonnegative; rejected0.2044 was not retained so its raw -0.01 coefficient cannot independently be reconstructed. Existing native logs explicitly show -0.01<0 negative correlation not allowed. Negative branch operates separately from >0.70 upperbound; no nearzero exemption in observed rejection. Do not claim an untested exact zero-boundary rounding tolerance.
CRITICAL SAFETY LESSON: DO NOT call /portfoliocorrelation/compute on multi-strategy portfolios while S001 runs. It automatically launches OverlappingTradesComputer after the matrix, with potentially huge retained overlap lists/threads. This audit inadvertently caused GC-overhead OOM at15:54 and S001 stopped itself. Native auxiliary analysis was stopped; a one-result/no-pair computation cleared analysis caches, then the existing unfinished Build1 was safely restarted16:05. Never repeat live full matrix/overlap analysis; use archived trade exports. Engine UI dismissalStats observer is distinct and did not initiate this matrix calculation.
PRESERVATION REPAIRED: native autosync during the failed TradeList lock removed B01__Strategy0.1350__38a85ae0de9e148a.sqx from disk (memoryrecord retained). While project stopped, exact immutable backup was copied to the missing path, SHA256AB6AA75954EE86F0BE06E8EEA314E74F2FC7698C1B54B3803DA9D9F99AB7A3DD verified. At16:26 ALL318 originalBuilder1files byte-hash-identical to04:52backup; ALL322currentBuilder1files hash-match complete recoverybackup. No missing/zero files. Source1350 one-row native trade read succeeded after recovery. Do not describe saved results as lost; report the temporary removal and verified restoration honestly. Full recoverybackup C:/Users/Vic/ERAZER-Tools/Backups/S001-analysis-recovery-20261029-1558 includes322/300/650builderfiles plus project and derivedanalysisarchive. Fourthnew0.3265 hash50757C59A02E1291CDD61768F71F852DE6C8F92B99C145258E647B4E3940DEB8.
TEMPORARY ANALYSIS BANK CLEANED: S001_CorrelationAudit_20261029 was created only for copied-results matrix, then native simulated portfolio saved, SHA256verified/archived, and only that temporary bank removed16:14. Original39banks and66tasks retained;1272projectstrategies excludes archivedderivedportfolio. Native merge did NOT create an accepted candidate. Derived Audit7_Strategies_20261029.sqx archive SHA2562FD7805B72CA1F47BBC241274B46C4D99A07F776E2ED11CD6FA4D5090F32BCCB stays in recoverybackup.
SETTINGS UNCHANGED SEMANTICALLY: native project-bank operations reformatted task XML whitespace. Original rawhash9c833032... superseded by68dcd095f4d72585a410fee43e8079d6f613aebd86240e62e13d18a3c70ddf8f; do not infer filter change from rawhash alone. ALLBuild-Task2XML text/attributes/order match pre-audit; semantic digest02a252568466c7641150e1948266e114b10f7ca2b0c9ebb2ae79ca0db1d4c6bf. Evidence final-settings-verification.json. Do not rewrite live archives to restore whitespace.
REPORT out/sqx-correlation-debug/correlation-audit.html. Current health final-live-status.json; full-builder-preservation-hashes.json; recovery-start.json; final-preservation-check.json. Continue visible hourly safe monitor/recovery; compare counters ONLY in same new16:05segment and task/iteration. Verify accepted-vs-saved counts and backup new acceptances; do not duplicate prior sync/update requests merely on missing log/timeout. Original885 data audit still885/885>=Oct22, targeted6endpointsOct27. RC1extra0.2876 remains separately preserved/unmerged. Historical B00/B01 preservation/finalexport audits and authorized isolated plugin tests still pending after true S001completion; separate @ES/COFUSUSD provider failures not certified fixed.

### Builder 1 target changed to 325 (2026-10-29)

At the user's explicit request, Builder 1's databank capacity was reduced from
500 to 325. Its stop condition remains `databank-full`. The required count in
`Flow-03-CallExternalScript.xml` was also reduced from `-MinimumCount 500` to
`-MinimumCount 325`; otherwise the namespace verification step would block
before Builder 2. Builder 1's name/title now reads
`Build 1: S001 Nasdaq template (cap 325)`. Builder 2 retains its existing settings.

Native settings editing required a graceful project stop. The project continued
in the same PID12348, same run suffix20261025095236452 at19:08:57 Shanghai, in
`global_log_20261029_110857.log`. Do not compare its new generation counters with
the earlier16:05segment. At continuation the builder banks retained323/300/650
records; Builder1 needs two further accepted records before the ordinary
archive/namespace/verified-load sequence advances to Builder2.

All67 project archive entries were checked semantically, allowing only the
three changes above. All1273 builder files matched SHA256verified backups before
continuation. Correlation/acceptance rules, costs, formulas, and other tasks did
not change. Evidence is in `out/s001-builder1-cap325/`; remote backup is
`C:\Users\Vic\ERAZER-Tools\Backups\S001-cap325-20261029-1915`
(the directory label is not the exact backup time, which is in the receipts).
The separate Strategy0.490 trade-data comparison remains pending and must use
archived data without live matrix/overlap analysis.
