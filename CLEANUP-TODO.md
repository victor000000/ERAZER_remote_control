# Pending work and verification

Updated **2026-11-02**. This is the open-work list; completed live work is in its
runbook and timestamped local evidence. The [historical checklist](docs/history/CLEANUP-TODO-before-restructure.md)
is preserved and is not a current action list.

## Active operations

- [x] Original885 refresh targets verified nonzero at or afterOct22; six targeted
      symbols advanced toOct27. This does not certify current queue state or caches.
- [ ] Observe current data activity without replaying old queues; retain separate
      @ES/COFUSUSD provider blockers and verify endpoints for any further repair.
- [ ] Back up every new S001 acceptance and verify all prior names using the
      [receipt chain](docs/s001-preservation.md). Notify Builder2 completion/issues.
- [ ] After genuine S001 completion, repair historical truncated6610 in an isolated
      copy first, retaining all variants and a verified rollback backup; native
      validation is required. See [repair procedure](docs/s001-preservation.md).
- [ ] Complete final export/exception audits, historical B00/B01 reconciliation,
      RC1 extra0.2876 review and Strategy0.490 archived-trade correlation comparison.
      See the [current handoff](docs/s001-current-handoff.md).
- [ ] Continue S001; inspect B03 namespace gates when reached. Use the
      [verified recovery procedure](docs/s001-operations.md#namespace-gate-recovery),
      preserve originals and verify actual task advancement. The B02 gate passed
      on 2026-11-02 at the agreed 386 target (386 namespaced copies, helper-written
      marker, A00 325→711, Dow retest started).
- [ ] Align the task 8 `-MinimumCount` with the agreed 386 target at the next safe
      project stop; it still reads 500, so the in-project namespace step throws
      immediately and the gate only advances when the helper is run with the
      approved count. Do not bypass the marker.
- [ ] Complete native SQX 145 migration checks in a separate idle/test context.
      The [asset audit](docs/sqx-asset-migration.md) is static evidence, not import approval.
- [ ] Verify physical cursor crossing and reboot/startup behavior for
      [MWB](docs/mouse-without-borders.md). Connected sockets and successful
      scheduled checks are already verified; no reboot was performed.

## Source and deployment

- [x] Verify [local Docker Desktop removal](docs/docker-cleanup.md).
      ERAZER runs natively. Desktop storage and startup entries are gone;
      Ubuntu and bind-mounted source files remain. No backups are requested.
- [ ] Reconcile controller autostart/routing defaults with the Mihomo project's
      current deployment before using restoration. Existing OMR names are stale
      evidence, not an instruction to re-enable that transport.
- [ ] Review the bundle manifest against desired deployment scope: the standalone
      MWB and migration-audit helpers are not automatically included.
- [ ] Run pinned full repository checks when changing implementation; record
      actual lint/test/coverage results separately from live checks. Historical
      suite passes do not certify later standalone helpers.
- [ ] Validate generic bundle migration and GUI-at-logon during a separately
      authorized deployment/logon window; do not replace S001's preserving task.

## Deferred historical investigations

These are inherited leads, not current fault diagnoses or authorized destructive
cleanup: antivirus posture; HONOR Fn/performance controls; audio after Nahimic
removal; WSL memory limits independently of this project's native runtime; and two formerly reported
corrupt strategies (`sp500_example_strategy/Strategy 0.8248.sqx`,
`dow_test/Strategy 0.21(1)(3).sqx`). Recheck before acting. Preserve strategy data;
confirmed bad assets require backed-up quarantine, never deletion.
