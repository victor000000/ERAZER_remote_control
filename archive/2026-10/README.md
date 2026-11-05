# October 2026 archive — unsupported historical scripts

**Do not run this archive as a toolkit or deployment bundle.** It contains
one-off, machine-specific scripts that can remove applications or data,
disable security protections, alter networking/firewall rules, register tasks,
reboot machines or manipulate the desktop. Preservation is not endorsement.
These scripts are **not covered operationally** by the maintained test suite,
and parse-only checking does not make them safe or supported.

- [`tools/`](tools/) preserves every original file from the former `tools/`
  collection, other than the raw inventory reports relocated to ignored local
  `out/history/`. Original `.cmd`/`.vbs` launchers are preserved here too.
- [`root/`](root/) preserves the original root PowerShell scripts, except
  `Connect-ERAZER.ps1`, which remains at the repository root and now requires
  explicit `-UpdateTargetRecord` before changing SSH/hosts records.
- Relative sibling layouts within each original directory are retained. Old
  absolute paths, old deployment assumptions and historical behavior have not
  been modernized. Cross-directory/root assumptions may no longer resolve.
- Two parse-compatibility corrections were made without running the scripts:
  [`tools/Mwb-CtrlTab.ps1`](tools/Mwb-CtrlTab.ps1) uses `${i}:` rather than
  invalid `$i:` interpolation; [`tools/Eject-Volume.ps1`](tools/Eject-Volume.ps1)
  constructs its Chinese-label regex from Unicode code points so Windows
  PowerShell 5.1 can parse the UTF-8 file without an ANSI decoding error.

The maintained replacements are in [`../../scripts/`](../../scripts/) and
[`../../src/ERAZER.RemoteControl/`](../../src/ERAZER.RemoteControl/). Use the
[compatibility mapping](../../docs/deployment-migration.md#compatibility-mapping)
for the small supported legacy-name surface. Other archived names have **no
supported replacement** implied by this move.

Original documentation is in [`../../docs/history/`](../../docs/history/).
Its past completion claims and network measurements are historical, not
live verification. Existing files deployed on ERAZER are untouched.
