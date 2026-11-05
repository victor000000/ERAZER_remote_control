# Builder 2 review hold — 2026-10-23

The user requested a project review after Builder 2 finishes and before S001
continues downstream. This supersedes automatic B02 namespace recovery.

## Installed hold

At 12:57 Shanghai, Builder 2 had most recently reported 260/300. The deployed
`C:\Users\Vic\ERAZER-Tools\SQX\Namespace-SqxFiles.ps1` now rejects prefix B02
with `S001_B02_REVIEW_HOLD` before creating directories, copying strategies or
writing a verification marker. Builder 2 can finish and export originals;
its existing file verification gate prevents loading B02 candidates or retesting.
If the external command reports an error instead, retain that intentional hold.

The live project archive was read to confirm the B02 file gate and was not
modified. The destination marker was absent. A dry invocation with nonexistent
source/destination verified the guard throws before creating output. The first
verification attempt was blocked by PowerShell execution policy; verification
then passed with process-only Bypass, matching the normal helper launch mode.
SQX remained PID 14444. No engine restart was performed.

Evidence: `../out/s001-builder2-review/hold-verification.json` and remote
`C:\Users\Vic\ERAZER-Tools\SQX\Builder2-review-20261023\hold-verification.json`.
The hourly automation was updated to recognize the intentional hold.

## Review when the builder reaches 300

1. Confirm current run, all bank counts, active task and export completion.
   Verify all 300 Builder 2 originals are archived and readable; retain every
   original, earlier bank, downstream copy and run.
2. Inspect the live project's task order, datasets/instruments, date ranges,
   templates, filters, crosschecks and downstream bank routing. Check that
   failed results remain retained and namespacing prevents collisions.
3. Assess the stalled historical-data update and whether the next tasks have
   complete required datasets. Record unresolved data readiness issues.
4. Inspect namespace launch behavior and source/destination state. Do not
   mistake the deliberate guard for the earlier conhost launch failure.
5. Save a review report with findings, evidence, safe corrections and remaining
   blockers. Do not advance with unresolved material findings.

## Release after review

Original helper backup:
`C:\Users\Vic\ERAZER-Tools\SQX\Builder2-review-20261023\Namespace-SqxFiles.original.ps1`

Expected original SHA-256:
`920E7666F19CA91B343669520CDD1254CEBA8B8EEF27C4EEAD2B82F3562D5FDD`

Installed guarded SHA-256:
`BA3CFACAEA8D673A4B387DE3904F08D7BABC4AA4C2B99FAADAF4223929EC0769`

After review, verify both hashes before restoring the original helper atomically.
If either differs, investigate intervening changes instead of overwriting them.
Then follow [namespace recovery](s001-operations.md#namespace-gate-recovery)
with actual B02 paths, minimum count 300 and the existing scheduled principal.
Require the helper's own content verification and real marker; never create a
marker manually. Verify actual task advancement and update the monitor prompt
and this document with the review and release evidence.

## Release initiated 2026-10-24

User requested continuation after review. Live symbol catalog confirms all 27 configured chart/date checks; review and data caveats are in `../out/s001-builder2-review/review-at-completion.md`. Original helper hash verified and restored atomically. Hidden task `SQX-Release-B02-20261024` runs normal B02 namespacing with minimum 300. Consult `release-verification.json` before any retry; partial copies must never be overwritten. The earlier installed-hold section is historical once restoration is verified.

Release verified at 06:46: task exit0; 300 copies verified, real marker, automatic resume06:45:40; Dow retest produced50 results. Same engine and run. Do not rerun release or reinstall the hold.
