# Historical documentation

These are retained historical snapshots and dated reviews. They
contain dated measurements, obsolete SQX 144 paths, old deployment locations
and earlier completion claims. They are **not current runbooks**, evidence of
live health or approval to repeat security-disable/cleanup actions.

- [Original README](README-before-restructure.md), preserved byte-for-byte.
- [Original cleanup checklist](CLEANUP-TODO-before-restructure.md).
- [Original ERAZER Windows review](ERAZER-Windows-Review.md).
- [October 20 gateway/OMR review](gateway-review-20261020.md), superseded by
  [current connections](../gateway-compatibility.md).

Relative links and inline paths inside these snapshots describe the **old**
repository layout. Resolve historical root scripts under
[`../../archive/2026-10/root/`](../../archive/2026-10/root/) and historical
`tools/` scripts under
[`../../archive/2026-10/tools/`](../../archive/2026-10/tools/).
`Connect-ERAZER.ps1` remains at the [repository root](../../Connect-ERAZER.ps1).
The CLI help remains at [`../sqx-cli-help.txt`](../sqx-cli-help.txt) and was
captured from SQX 144.2953, not revalidated against 145.

The raw `local-cleanup-log.txt`, `windows-review.txt` and
`local-network-review.txt` were retained intact locally under ignored
`out/history/`; they are no longer tracked. They are deliberately not linked as
published repository artifacts.

Use the [current README](../../README.md), [safe operations](../safe-operations.md),
[deployment migration](../deployment-migration.md) and
[pending checks](../../CLEANUP-TODO.md) instead. The archive contains
unsupported and potentially destructive scripts, not an operational fallback.
