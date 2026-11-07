# S001 current handoff and recovery decisions

> Public-source scope correction, 2026-11-07: the October baseline below is
> historical. The native operator workspace has a newer November 7 handoff and
> next-cycle instructions that are not copied into this public snapshot. Read
> that current authorized ledger and obtain fresh identity/progress evidence
> before acting; old builder counts and restart prohibitions below describe the
> October run. This source review does not authorize any lifecycle operation.

Documentation baseline: **2026-10-31 06:18 Asia/Shanghai**. This is a dated
handoff, not a live health assertion. Obtain a fresh snapshot before acting.
This document takes precedence over older process IDs, launch examples and
capacity descriptions in the [operations history](s001-operations.md).

## Reading order and authority

1. Read this handoff and [safe operations](safe-operations.md).
2. Verify access using [connections](gateway-compatibility.md).
3. Follow [monitoring](sqx-monitoring.md), then [preservation](s001-preservation.md).
4. Use the operations history for the exact archive/namespace workflow, not as
   permission to replay a dated launch or restart.

The user wants S001 kept running, ERAZER connectivity monitored, every new
accepted strategy backed up and SHA256 verified, and notification when Builder 2
finishes or anything needs attention. Historical file repair is explicitly
scheduled **after S001 finishes**, with all originals retained. Existing final
export, data, preservation, correlation and plugin follow-ups remain required.
An old one-time restart or process-termination approval is consumed, not reusable.

## Last verified state

| Item | Verified value |
| --- | --- |
| Host / install | ERAZER-6JMHAKCD / `C:\StrategyQuantX145` |
| Engine | GUI `StrategyQuantX.exe`, PID12992, launched Oct31 05:10:52 |
| Project / bank run | `S001_reproduce_project` / `20261025095236452` |
| Active task | Task 6, Build 2, iteration 1, capacity 500 |
| Current log segment | `global_log_20261030_211502.log` |
| Native counters | Generated188 / Accepted0 at 06:17:52 |
| Measured progress | +133 candidates in2306.47 seconds since 05:39, about207.59/hour |
| Saved builder records | B01=325, B02=326, B03=650; total1301 |
| Derived records | A00=325; project total1626 |
| Retention | All 326 prior B02 names present; no new acceptance in06:18 check |
| Health sample | CPU87.1%, working set22.99GB, available3336MB, paging inputs/outputs0/0 |
| Remaining / ETA | Builder 2 needs 174 more saved acceptances; reliable ETA unknown |

Builder 1 is complete at 325; **never restart Builder 1**. Configured builder caps
are now325/500/1000. The third builder's bank is named
`S001_build_10_sp500__r20261025095236452`; do not infer bank names from display
order. Retests had not started. A00 records are derived copies, not additional
accepted builder strategies. Zero acceptances does not mean generation stopped.

Evidence: `out/sqx-monitor/20261031-0618-{current,comparison,new-backup}.json`
and `out/s001-data-repair/20261031-0618-progress.json`. These are ignored local
artifacts; a clean checkout does not contain them. Restore the evidence and
private access configuration securely before operating from another workspace.

## Why the engine identity changed

Old PID4216 exited itself at 04:36:58 with the native message
`Exit app - License re-check failed - cannot reach the license server.`
Network loss alone did not establish this; the log and process inspection did.
After the user explicitly reauthorized keeping S001 running:

- Ten overnight acceptances were preserved; all 316 prior B02 names remained.
- All 8519 offline project files were copied and SHA256 verified under
  `C:\Users\Vic\ERAZER-Tools\Backups\S001-network-exit-20261031-0510`.
- The existing GUI145 executable was launched once. After A00 loaded all 325,
  the exact unfinished Build2 task started once at 05:15:02.489.
- Native data preparation, successful initial test and generation start appeared
  at 05:15:09.374; a completed candidate at 05:18:32 proved actual progress.
- All 67 project archive entries were semantically identical to the offline backup.

Evidence is under `out/erazer-connection-recovery/20261031-*.json`, including
`offline-verified`, `project-semantic-check`, `builder2-start` and `final-retention`.
The new counters reset. Never subtract counters from PID4216's old segment.
GUI heap remains Xmx29GB / Xms16GB; no further restart is authorized by this receipt.

## Recovery decision table

| Observation | Next action |
| --- | --- |
| Pinned SSH unavailable | Bounded discovery; save failure evidence; report current engine state unknown. Do not infer stop or cycle radios blindly. |
| SSH works, GUI login times out | Inspect process/listener and current logs; allow startup or paging. Do not start another engine. |
| Correct task advances | Preserve new results and leave the engine running. |
| Native state explicitly paused | Verify task/run, then use supported native resume within existing authorization; verify progress. |
| Native state explicitly stopped before completion | Verify exact unfinished task/run, preserve project and banks, then use existing GUI native start-from-here within continuous-run authorization. |
| Start request times out | Inspect task-start logs/state before any further action; it may have succeeded. |
| Engine exited | Preserve exit evidence and results, assess existing authorization and safe recovery. Previous one-shot approvals do not authorize another launch. |
| Archive marker guard waits | Verify archive completeness and actual helper outputs; follow the namespace recovery procedure. Never fabricate the marker or bypass Load/validation. |
| Builder 2 reaches 500 | Preserve and verify files, confirm native completion/normal handoff, notify the user; do not manually skip to the next task. |

No live archive edits, forced GC/working-set trimming, historical-bank loads,
second engine, hot plugin installs, or multi-strategy portfolio-correlation
computations while S001 runs. The last operation can automatically launch
expensive overlap analysis and previously caused an OOM stop.

## Completion gates and unresolved work

S001 completion requires actual native end-of-project evidence and an export
and exception audit, not a stored `Passed` flag. Keep monitoring active through
these follow-ups, or report concrete blockers explicitly:

- Preserve all builders, namespace copies, archives and final exports; reconcile
  task input/output counts and per-strategy test exceptions.
- Repair the historical truncated6610 duplicate using the preservation runbook.
- Audit historical rerun B00 (105 live versus658 expected) and B01 (608 versus658).
  B01 archive name coverage does not prove B00 byte identity. Do not load these
  banks during the active build.
- Reconcile the separately preserved RC1 extra `Strategy 0.2876.sqx` deliberately.
- Complete Strategy0.490 archived-trade versus actual SQX correlation comparison;
  previously matched 21 pairs at displayed 2 decimals do not certify this strategy.
- Retain original-run exceptions: B03 Strategy0.534 symbolInfo failure, B10
  17 inputs/16 saved with B01 Strategy0.1057 absent, and B09 AABA array errors.
- Original 885 data-refresh targets were verified nonzero at or after Oct22;
  six targeted symbols advanced toOct27. Do not replay the old bulk queue.
  Current queue requires fresh evidence; @ES/COFUSUSD remain separate unresolved
  provider issues. Stored data advancement does not prove running cache refresh.
- Run authorized isolated [plugin tests](sqx-asset-migration.md) only after run,
  data and required audits finish. Record real compile/load/backtest/export
  evidence; static ZIP/CRC checks are insufficient.
