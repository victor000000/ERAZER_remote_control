# Safe operations

Use this checklist for changes; follow the topic runbook for the actual command.
Existing user authorization persists. Do not add a new approval step for every
read-only check or reversible repair already within that authorization.

## Before changes

- Confirm machine, user, current task and intended effect. SQX's loopback API
  queries the executing machine; the controller is not the SQX host.
- Inspect actual deployed files/actions before using source defaults. Editing
  this repository or staging a bundle does not update the running deployment.
- Preserve user changes and keep rollback evidence outside live write paths.
  Never publish credentials, license material or private keys.
- Access denied is not absence. Do not replace tasks or settings based on an
  incomplete query. Use the required context for the authorized operation.

## Connections and persistent work

Use [the connection runbook](gateway-compatibility.md). Keep pinned SSH host
identity and saved Wi-Fi profiles. Controller Tailscale is removed and must not
be restored as an incidental fallback. Network switching needs target-local
rollback independent of SSH and actual target-side proxy validation.

Persistent remote work uses scheduled tasks, not SSH child processes. Prefer
hidden, noninteractive PowerShell. SYSTEM tasks must execute administrator-
controlled files. Do not reuse or overwrite an unrelated task for elevation.

## SQX and strategies

Read [S001 operations](s001-operations.md) before lifecycle work. Preserve every
strategy, current run and bank map. One engine per installation; no force-kill,
parallel GUI/CLI instance, live `.cfx` edit or fabricated verification marker.
Back up and verify before an authorized offline replacement. GUI-at-logon
settings are not changed as a side effect of on-demand headless work.

The deployed S001 task uses the preserving launcher. Generic
`Register-SqxTask.ps1` / `Start-SqxProject.ps1` expect a different action and must
not replace that task merely to satisfy their checks. Module 1.0.1 enforces the
reserved name in registration and rejects uncertain task states. This does not
remove the inspection/mutation race or protect renamed preserving tasks. Generic toolkit
procedures are in [deployment migration](deployment-migration.md).
Project stop and engine exit are distinct; use previews and inspect status
before a deliberate stop. A GUI save/exit dialog needs desktop confirmation.

Monitoring permits verified reversible recovery but does not authorize
restarting historical-data updates or importing assets into a busy install.
Use [monitoring](sqx-monitoring.md) and [asset migration](sqx-asset-migration.md).

## Verification and scope

Verify actual process/counter/task advancement after recovery. Record timestamps
and limits under ignored `out/`. Passing offline tests is not evidence of live
licensing, task principals, GUI behavior, boot recovery or network performance.
A reported connection failure alone does not establish an SQX crash.

Use [testing](testing.md) for offline checks and [pending checks](../CLEANUP-TODO.md)
for open work. Never execute archived cleanup/security-disable scripts. During
an authorized reboot, save SQX data and arrange recovery first; afterward verify
access, route, task policy and engine health without silently changing policy.
