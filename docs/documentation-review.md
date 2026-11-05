# Documentation review — October 21, 2026

Scope: repository documentation and navigation only. No live engine, network,
service, task, project archive or strategy asset was changed in this pass.
Existing source/configuration/test changes and raw CLI help were preserved.

## Findings and revisions

| Finding | Revision |
| --- | --- |
| README, instructions and network review disagreed about OMR/Tailscale and addresses | One current connection runbook; dated OMR review retained in history; stale source defaults explicitly flagged |
| Blanket “source-only” claims obscured later live S001/MWB deployments | Distinguish original restructure, current source edits, generic staging and separately verified deployments |
| Generic task starter could be mistaken for preserving S001 launcher | Explicit task-action distinction in README, safe operations, deployment and S001 runbooks |
| Monitoring behavior and ETA rules lived mainly in chat/automation | Added durable monitoring runbook covering generation, data queue, evidence and ETA limits |
| Namespace gate recovery was hard to find | Added source/destination checks, verified helper recovery and no-bypass rules to S001 |
| MWB documentation lacked concrete operation/rollback guidance | Added installed task behavior, both address pairs, commands, privilege and DHCP limits |
| Extensive migration audit was buried in ignored output | Added audit index, provenance, scanner usage and native-validation conditions |
| Old checklist mixed completed work with inherited faults | Focused pending list; retained historical leads with explicit uncertainty |
| Entry points repeated long operating instructions | Short README/instructions plus task-oriented documentation index |

## Verification

Checked current Markdown links/anchors and referenced local artifacts, source
parameter names, preserved historical body, and whitespace/diff scope. Results
are retained in `out/docs-review/validation.json`. The Markdown diff passes whitespace checks. An unrestricted diff check also
reported pre-existing line-ending/whitespace changes in `docs/sqx-cli-help.txt`;
that raw capture was left untouched. Runtime checks and broad
implementation tests are outside this documentation pass; no new live-health
or native-migration claims were inferred from prose validation.

## Remaining boundaries

Controller autostart defaults still require reconciliation with the Mihomo
project; generic bundle migration and cold boot remain separately verifiable.
The static migration audit is not native import certification. MWB known-address
fallback cannot discover arbitrary DHCP changes. All current counters belong in
monitoring snapshots rather than evergreen operating instructions.
