# Strategy preservation and historical repair

Use with the [current handoff](s001-current-handoff.md). Never trade result
preservation for faster generation, easier loading or a cleaner bank listing.
The backup root on ERAZER is `C:\Users\Vic\ERAZER-Tools\Backups`.

## Incremental backup transaction

1. Verify actual project/run and enumerate the relevant bank without loading it
   into a historical project. Record file names, lengths and write timestamps.
2. Build the prior-name set from the full baseline manifest plus **every** later
   nonempty receipt's `NewFiles`. Verify no prior name disappeared. If any is
   missing, preserve evidence and investigate before claiming retention.
3. Compare current names against that union. Use a new, timestamped destination;
   refuse an existing destination so a timeout cannot silently overwrite evidence.
4. For each new file, SHA256 the source, copy it, and SHA256 the copy. Require an
   exact match. If a concurrent save makes verification fail, keep the failed
   copy/evidence and assess stability before a separate attempt.
5. Save a receipt containing timestamp, bank/run, current count, previous-name
   count, missing names/count, destination, and each new file's name, length,
   write time, SHA256 and verification outcome. Persist the remote receipt and
   a local copy. Only a verified receipt establishes backup completion.
6. Add every new receipt to future retention checks. An empty receipt records a
   successful no-new-files check but adds no names.

A transport timeout is not proof the copy failed. Inspect destination, receipt
and file hashes before deciding what remains. Never blindly rerun a mutation.
A count alone cannot detect replacement of one strategy by another. Name
retention and copy hashes serve different purposes; both are required.

## Existing B02 receipt chain at Oct31 06:18

Bank: `S001_build_02_random__r20261025095236452` under
`C:\StrategyQuantX145\user\projects\S001_reproduce_project\databanks`.

| Backup directory under the backup root | Manifest / additions |
| --- | --- |
| `S001-B02-20261030-1208` | `hashes.json`, full301 files |
| `S001-B02-new-20261030-1304` | `receipt.json`, +2 |
| `S001-B02-new-20261030-1408` | +2 |
| `S001-B02-new-20261030-1719` | +3 |
| `S001-B02-new-20261030-1823` | +1 |
| `S001-B02-new-20261030-1928` | +1 |
| `S001-B02-new-20261030-2028` | +2 |
| `S001-B02-new-20261030-2124` | +2 |
| `S001-B02-new-20261030-2223` | +2 |
| `S001-B02-new-20261031-0508` | +10; cumulative326 |

All increment directories use `receipt.json`. The0520 and0618 receipts contain
no additions. The prepared local script
`out/sqx-monitor/20261031-next-preserve-template.ps1` includes the chain through
0508. **It is a template:** replace its `NEXT` destination and incorporate any
later receipts before execution. Never use an old template as a complete ledger.

PowerShell JSON arrays need care. Assign the baseline directly from
`ConvertFrom-Json`, then concatenate receipt arrays; an accidentally nested
array can produce a false missing null name. Explicit empty output arrays should
use `@($missing | ForEach-Object { $_.Name })`. Validate the count and actual names,
not just successful script exit.

## Full preservation before recovery

Preserve the project configuration and all strategy files before a verified
stopped-run recovery, and use an offline complete backup before any authorized
engine relaunch. Record relative paths, sizes and hashes, then independently
verify the destination. Preserve partial derived banks separately before any
carefully justified replacement/import; do not discard them to simplify loading.

Known full offline recovery backup:
`S001-network-exit-20261031-0510`,8519 project files with
`verified-hashes.json`. October30 archive/namespace copies and all earlier
immutable backups remain retained. These are not cleanup candidates.

Native autosync can reserialize `.sqx` or XML without changing strategy logic.
A raw hash difference requires investigation; it is not alone proof of filter
changes or permission to restore old bytes. Compare archive entry content and
XML semantics where appropriate. A copy hash proves integrity at copy time,
not correctness of strategy tests or equality of all historical variants.

## Historical6610: diagnosis and preserved variants

Affected historical file, **not the active S001 bank**:

```text
C:\StrategyQuantX145\user\projects\S001_timing_20261020\databanks\Build01\B01__Strategy 0.6610__639cb5db6697aa72(1).sqx
```

The 83588-byte file is a truncated ZIP. Four preceding entries were recovered
with matching CRC/size; EOF occurs inside deflated
`Results/[[Nasdaq 100]]/dailyEquity.bin`. Central directory, end-of-ZIP record,
orders and version tail are absent. This explains the native ZIP-header error;
the cause of the incomplete write is unproven.

| Variant | SHA256 |
| --- | --- |
| Damaged duplicate | `0CF32D704A4D73E635D22356A0B6F709BD8EF8E41A6B4FC322B0E2BD2D7843AF` |
| Intact sibling without `(1)` | `68F6E4FC12AC35F7A05B66B50A1A7376036AD64DF29C6F0B69F0D42875DF67DE` |
| Intact archived copy | `1717DD142096323E0D0FB9D9FF606BDF41C16FBA26975BA0AC89F297FC162083` |

The damaged original is backed up under
`S001-historical-load-error-20261031-0520`. The intact archive came from
`C:\Users\Vic\ERAZER-Tools\StrategyArchives\S001_reproduce_project\run-20261020-144836-994-3848\build01_all`.
Local preserved copies and diagnosis are in
`out/erazer-connection-recovery/historical-6610-*`.

Both intact variants pass ZIP CRC checks for all 7 entries. Their strategy,
lastSettings, equity, orders and version entries match. The damaged strategy and
lastSettings also match, and surviving equity matches a prefix. However,
`settings.xml` differs in result naming and serialized statistics. Therefore
neither intact copy is certified an exact replacement of the duplicate. No
hybrid file has been made and no missing trades have been fabricated.

## Authorized repair after S001 genuinely finishes

1. Confirm genuine completion and preserve final outputs before historical work.
   Verify an idle safe maintenance context; do not interrupt the current build
   or load this historical bank while it runs.
2. Re-hash and retain the damaged original, intact sibling and archive, plus
   current historical bank/project configuration. Keep independent immutable
   copies and a rollback manifest mapping each original path to its backup.
3. Compare settings, statistics, strategy, trade/equity content and provenance.
   Search available immutable backups for an exact complete duplicate first.
   Do not select a sibling merely because the filename looks similar.
4. Prepare recovery in an isolated copy. If exact recovery is impossible, retain
   both distinct results and document unrecoverable content; do not silently
   replace differing results or invent trades/statistics.
5. Validate ZIP structure/CRC and actual native load/export behavior in an
   authorized idle context. ZIP validity alone is not successful repair. Check
   names, strategy logic, settings, statistics, trade/equity and retained records.
6. Only after validated recovery, perform a backed-up, reversible historical-bank
   repair consistent with native loading/autosync behavior. Retain damaged bytes
   outside the active load path if quarantining is necessary; never delete them.
7. Reopen/validate the repaired historical result, verify unrelated bank records
   remain, and record exact changes, hashes, validation and rollback outcome.
   Report any remaining mismatch or missing content rather than claim full repair.

This repair remains pending. Preserve other historical discrepancies and final
export audits listed in the handoff; repairing6610 does not resolve them.
