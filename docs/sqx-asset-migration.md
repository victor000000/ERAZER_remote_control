# SQX 144 assets for SQX 145

The October 21 review inspected assets from the original Taobao archive and
preserved newer files from its previously extracted folder. **No assets were
imported, executed or compiled in the running SQX 145 installation.** S001 was
kept running. Static compatibility findings still require native validation.

## Evidence and retained data

| Item | Location / meaning |
| --- | --- |
| Original RAR on ERAZER | `C:\strategyquant 144.rar`; retained and tested with trusted 7-Zip |
| Clean full extraction | `C:\Users\Vic\ERAZER-Tools\SQX\Taobao144-review\full-original` |
| Newer-folder delta backup | `C:\Users\Vic\ERAZER-Tools\Backups\Taobao144-folder-delta-20261021.7z` |
| Local report directory | `out/taobao144-review/recheck/` |
| Report entry points | `report.html`, `asset-migration-report.txt`, `sqx144-to-145-individual-review.zip` |
| Full checklist | `file-by-file-checklist.csv`: 42,901 entries, including backed-up newer files |
| Remote report copy | `C:\Users\Vic\ERAZER-Tools\SQX\Taobao144-review\individual-recheck` |

The old `C:\strategyquant144taobao` folder was removed only after preserving
10,340 newer/different files, including 209 strategy archives. The original RAR,
clean extraction and verified delta backup remain. Do not repeat this deletion
or assume the RAR contains those newer files. Hashes and verification evidence
are in `out/taobao144-review/completion.json` and the detailed report.

## What the audit supports

| Asset | Finding | Migration condition |
| --- | --- | --- |
| Historical data | Many original files are tiny placeholders; newer backup contains substantial data | Reconcile provider/alias, dates, sessions, adjustment and metadata IDs; validate actual bars |
| Standard platform library | 111 original top-level files match 145 byte for byte | No benefit from replacing identical target files; this is not whole-installation identity |
| Blocks and random groups | 53 original definitions, 7 groups; some group references missing | Repair references and compare semantics before importing; preserve target definitions |
| Extension packages | 88 unique packages; one corrupt package, plus payload/class conflicts | Exclude corrupt package; resolve collisions and compile with 145 |
| Java extensions | Eight fully qualified class names have conflicting bodies | Choose/reconcile implementations in an isolated compile context |
| MT5 sources | Deduplicated user and standard source inventory retained | Inspect dependencies, compile and compare target output; do not overwrite by filename |
| TradeStation/MultiCharts | ELD/PLA bundles and export templates retained | Binary bundles alone do not prove editable source availability |
| Workflows | 62 need preservation-related rewrites; 51 empty shells | Review task paths, filters, bank caps and failed-strategy retention before use |
| Templates/strategies/settings | Per-file checklist and comparisons retained | Reconcile dependencies and test native loading on copies |

Use the detailed CSVs for individual decisions. A same-name record is not
necessarily the same vendor dataset; a valid ZIP or identical byte hash does
not establish native compatibility, strategy quality or current data freshness.

## Reusable review

The maintained scanner is
[Review-SqxMigrationAssets.py](../scripts/sqx/Review-SqxMigrationAssets.py).
It reads sources/target and writes CSV/JSONL to a separate output directory;
it never imports or executes source assets. Run with trusted Python:

```powershell
python .\scripts\sqx\Review-SqxMigrationAssets.py `
  --source 'original=C:\Audit\clean-extracted-install' `
  --source 'supplement=C:\Audit\preserved-newer-files' `
  --target 'C:\Audit\SQX145-reference-copy' `
  --output 'C:\Audit\new-review-output'
```

These are example audit paths. Use a fresh output and a consistent target data
snapshot/reference copy. Do not raw-copy a live SQLite file; use a read-only
SQLite online backup when a fresh metadata snapshot is needed. Keep full
reports local rather than committing vendor assets or raw inventories.

## Migration procedure

1. Retain source provenance, backups and target rollback copies.
2. Resolve the exact CSV findings for each selected item; do not copy the entire
   old install over 145 or merge all settings wholesale.
3. Perform native compilation/import checks in an isolated, idle 145 context.
   Later build compatibility is not established by this static review.
4. Test representative history, custom-block generation, platform export and
   workflow preservation. Compare results and archive originals.
5. Deploy only reviewed assets through an explicitly authorized plan outside
   the active S001 write path. Record each acceptance/blocker in the checklist.

Official guidance consulted: [StrategyQuant data migration between versions](https://strategyquant.com/ja/doc/strategyquant/data-migration-between-strategyquant-version/)
(the English route redirected during review; this retained the guidance), and
[random-group skills](https://strategyquant.com/codebase/random-groups-skills/).
Recheck vendor guidance for a future version pair; it does not replace the
per-asset findings or the native checks above.

## Conflict resolution trial, October 24

First offline candidate batch is in `../out/sqx-plugin-resolution/` with
`resolution-report.txt`, `candidate-manifest.json`, and `candidate-batch.zip`.
Four original packages (EfficiencySuperTrend, VWAPATRBands, ZScore, EntropyMath)
were staged with matching Java and platform templates, with ZIP CRC/hash checks.
No package has been compiled, installed or functionally certified in 145.

Correction to the earlier damaged-package finding: the two damaged
EfficiencySuperTrend copies have SHA256 beginning `2fbc79ee`, while an intact
original `SXP_import_here/22122025_EfficiencySuperTrend.sxp` copy has SHA256
`49eb4aed95fb025cb8518c7e67cd98cbc200160b6fc2f1fd066b892aa52e7599`.
The latter is now the staged replacement candidate, not a proven native plugin.

All eight conflicting classes have preserved variants and decision records.
Packaged indicator baselines are test candidates only: modified output/input
interfaces and EntropyMath formulas must not be silently substituted in existing
strategies. CNStockStampTax remains blocked on quantity/notional semantics.
All 53 custom blocks have per-definition diffs; the 11 missing group wrappers
remain unresolved in the searched local XML and archive payloads. Native checks
are deferred until the active rerun and data queue are idle; no second engine
or hot installation is authorized by this trial.

## Expanded offline preparation and authorized native follow-up

On October 24 the user requested continuing migration without interrupting S001,
then testing plugins after the rerun and data updates finish.
`../out/sqx-migration-next/README.txt` specifies the idle gate and acceptance
procedure. All 87 intact unique packages were staged with hash/CRC checks;
68 are static compilation candidates and 19 need collision/dependency review.
The broader package scan found 14 conflicting classes across packages, distinct
from the earlier eight loose-source conflicts, plus 18 native-type overlaps.
The 69-item test queue includes the four first-batch packages (ZScore isolated
from its competing package) and 65 other candidates. None is natively tested.

Per-file workflow and template plans cover 188 and 2,222 entries respectively.
The existing hourly monitor now retains the plugin follow-up after S001/data
completion; it must not hot-install, start a second engine, silently restart,
or treat static checks as acceptance.
