# Documentation index

Use the runbook for the operation rather than a historical log or an old chat.
For active S001 work, start with [the current handoff](s001-current-handoff.md),
then monitoring and preservation. Documentation refreshed October31,2026; dated
observations must be rechecked before action.
All recorded times are Asia/Shanghai unless explicitly stated otherwise.

| Document | Owns |
| --- | --- |
| [Connections and proxy](gateway-compatibility.md) | Known routes, host identity, discovery, proxy boundaries |
| [Current S001 handoff](s001-current-handoff.md) | Dated state, authorization boundaries, recovery decisions and completion gates |
| [Strategy preservation](s001-preservation.md) | Receipt chain, SHA256 verification, historical6610 repair and rollback |
| [S001 operations](s001-operations.md) | Preserving launcher, bank routing, archive gates, recovery |
| [SQX monitoring](sqx-monitoring.md) | Live checks, historical-data log parsing, snapshots, ETA/report rules |
| [Mouse Without Borders](mouse-without-borders.md) | Installed reconnect tasks, known-address fallback, rollback |
| [SQX asset migration](sqx-asset-migration.md) | 144 audit provenance, reusable scanner, migration limits |
| [Safe operations](safe-operations.md) | Rules shared by mutating operations |
| [Deployment migration](deployment-migration.md) | Generic toolkit staging, task compatibility and activation |
| [Testing](testing.md) | Offline verification and CI limits |
| [Docker cleanup](docker-cleanup.md) | Native environment decision and removal of unrelated local Docker data |
| [Pending checks](../CLEANUP-TODO.md) | Open issues and acceptance evidence needed |
| [Raw CLI help](sqx-cli-help.txt) | Historical capture; not a verified SQX 145 command contract |
| [History](history/README.md) | Superseded observations; never current instructions |
| [Documentation review](documentation-review.md) | Changes made in the October 21 documentation pass |

## Updating documentation

- Give each operating fact one main runbook; link to it elsewhere.
- Separate deployed behavior, source defaults and proposed changes. A successful
  source check does not establish a live deployment or current health.
- Keep per-check counts, logs, inventories and generated migration tables in
  ignored `out/`. Link evidence from a durable runbook without copying every row.
- Date route observations and retain verification limits. A timeout means an
  access failure, not proof that SQX stopped. Old PIDs/counts are historical.
- Preserve original history and user changes. Label superseded reviews and link
  their replacement. Do not move or rewrite live scripts while editing docs.
- Validate local links, command parameters and source/deployment distinctions
  after edits. Do not publish secrets or raw credentials.

## Evidence portability

Maintained source is under `scripts/`; `out/` contains ignored local helpers,
receipts and snapshots, not a reproducible clean-checkout deployment. Keep a
secure copy of required evidence and SSH/GUI configuration separately. Never
commit credentials or tokens. A missing receipt is an audit gap, not permission
to assume a backup succeeded. See preservation for the complete receipt chain.
