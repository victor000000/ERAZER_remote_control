# Documentation audit — 2026-11-07

Scope: all owned documentation in the published repository and its native
working checkout, against published module 1.0.1. This is documentation/source
verification, not a fresh operational audit. No target connection, scheduler
mutation, installation, data acquisition, strategy execution or cleanup was used
for verification. The module version is unchanged by this documentation revision.

## Inventory and disposition

The starting inventory contained **24 Markdown files** plus the historical raw
CLI capture. The revision adds four canonical references and this audit, for
**29 Markdown files**. The native checkout has the same starting path inventory;
its active S001 handoff and testing guide differ from the publication baseline.
Neither is silently overwritten. Ignored private evidence is not owned published
documentation and is not packaged as a prerequisite.

| Owned document / group | Review disposition |
| --- | --- |
| [README](../README.md) | Onboarding now works without ignored helper scripts; version, source-vs-runtime dates and canonical navigation corrected |
| [Project instructions](../CLAUDE.md) | Preservation/privacy/host rules reviewed; new reference navigation added; no operational policy relaxed |
| [Pending checks](../CLEANUP-TODO.md) | Dated native acceptance items retained; source-check disposition linked separately |
| [Documentation index](README.md) | Canonical ownership and publication/private evidence distinction clarified |
| [Architecture](architecture.md) | New implemented component, failure-state, file-contract and provenance rationale |
| [Configuration](configuration.md) | New precedence/schema/defaults reference; stale controller expectations and incomplete loader validation made explicit |
| [Command reference](command-reference.md) | New script/effect/parameter and status-result contract; CLI/GUI distinction and specialized helper limits |
| [Troubleshooting](troubleshooting.md) | New symptom/evidence/recovery guide; no implied restart/replay authorization |
| [Testing](testing.md) | Python/PowerShell gates distinguished, exact bootstrap commands and doc-check exclusions documented |
| [Deployment](deployment-migration.md) | Manifest/staging behavior checked; 1.0.1 reserved-task protections reconciled |
| [Safety](safe-operations.md) | Shared guard semantics and remaining race/renamed-task limits clarified |
| [Connections](gateway-compatibility.md) | Discovery/transport arguments and dated route evidence reviewed; no new reachability claim |
| [Monitoring](sqx-monitoring.md) | GUI/private-helper dependency marked; schedule policy separated from verified schedule state |
| [Published S001 handoff](s001-current-handoff.md) | October evidence preserved; explicit supersession notice for newer native operator ledger |
| [S001 operations](s001-operations.md) | Dated launch recipes and old caps marked historical; no live workflow rewrite |
| [Preservation](s001-preservation.md) | Receipt union, names/hashes, duplicate-retry and repair gates reviewed; dated receipt evidence retained |
| [Builder 2 hold](s001-builder2-review.md) | Historical hold/release body retained with current-ledger pointer |
| [MWB](mouse-without-borders.md) | Source flags/absence of WhatIf and private deployment prerequisites reviewed; dated evidence retained |
| [SQX migration](sqx-asset-migration.md) | Scanner parameters, read-only SQLite and output/native-validation limits reviewed |
| [Native environment/Docker](docker-cleanup.md) | Initial inventory put in past tense; dated removal evidence retained, no new cleanup |
| [Earlier doc review](documentation-review.md) | Original October 21 report retained with this supersession pointer |
| [Release 1.0.1](releases/1.0.1.md) | Prior release record reviewed and unchanged; not rewritten with this phase's results |
| [History index](history/README.md) | Current navigation checked; original layout caveat retained |
| Four files under history (original README/checklist/Windows review/gateway review) | Frozen records retained; old relative links explicitly excluded from current-link acceptance |
| [Archive index](../archive/2026-10/README.md) | Unsupported/destructive-code boundary reviewed; parsing is not operational certification |
| `docs/sqx-cli-help.txt` | Raw SQX 144 capture retained; not the 145 CLI contract |

The four excluded snapshots are individually listed in
[the doc checker](../build/check_docs.py). They are four files, not four additional
current guides. The other **25 Markdown files**, including this audit and the
history/archive indexes, are checked for current local links/fragments.

## Native and published reconciliation

The native S001 handoff contains newer November 7 continuation/next-cycle
observations. Its operator owner retains the authoritative private ledger. The
published October baseline is explicitly historical; no private process IDs,
current strategy counts, endpoints, receipts or authorizations were copied to
make the public snapshot appear current. Source commands are documented as
implemented, including CLI-specific limitations; private GUI helpers are not
claimed as clean-checkout functionality.

Separate local documentation commits track the reviewed native guide baseline
and then revise native README/index/safety/deployment/monitoring and the new
reference guides. The active S001 handoff is byte-identical to the captured
pre-review copy and excluded from staging; native code/config/test edits and
runtime/data artifacts remain outside this docs work. The native branch is not
pushed. Its links were additionally checked against the actual native tree.

All 15 documented generic/native script interfaces were compared byte-for-byte
against the reviewed publication source. The native testing guide explicitly
marks new doc-check scripts/CI as publication-only instead of claiming they exist
in that checkout. Prior published CI/encoding/environment corrections are
retained. New architecture/configuration/command references describe implemented
shared behavior without assuming synchronization of private deployment state.

## Verification and limits

Run the commands in [testing](testing.md). The doc gate checks local inline links
and ATX heading fragments, regression-tests its failure detection, and uses AST
metadata for the command-reference parameter annotations. It does not execute
remote, repair, install or lifecycle examples, fetch URLs, certify all Markdown
extensions, inspect private evidence, or assert vendor API compatibility.

Safe config-load and synthetic proxy examples are exercised separately with no
network/system mutation. Existing pinned PowerShell checks retain parsing, safety
lint, fixture tests, secret-pattern scanning and module coverage acceptance.
CI now includes the doc gate. Exact local and final published-commit results are
recorded separately in ignored `out/docs-review-20261107/` and coordinator records;
local results must not be described as a new hosted run.

Remaining limitations: native/private handoff freshness, actual host routes,
licensing, GUI/task principals, deployed helper versions, receipt completeness,
native asset import and economic/research acceptance still require their own
evidence. Earlier dates and test counts remain historical. This audit neither
refreshes runtime state nor claims production readiness.
