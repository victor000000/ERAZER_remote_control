# Cleanup TODO — local PC (StupicVicPC) and ERAZER

Last updated: 2026-10-19 (final pass). Scripts: `tools/Apply-LocalCleanup.ps1`,
`Apply-LocalCleanup2.ps1`, `Apply-HonorRemoval.ps1`, `Apply-PCManagerCore.ps1`,
`Apply-XboxRemoval.ps1`, `Apply-FinishCleanup.ps1`, `Apply-DefenderDisable.ps1`,
`Apply-FinalRemovals.ps1`, `Apply-RemoveLockedRemnants.ps1`.
Log: `local-cleanup-log.txt`.

## Done on the local PC

- [x] Recall ("回顾") disabled (feature + policy).
- [x] `DiagTrack`, `MapsBroker` disabled; promo/updater tasks disabled.
- [x] Temp + Windows Update cache cleared (~1.8 GB).
- [x] Suggestion/ads flags off; `NlaSvc` repaired; Tailscale UDP rule added;
      hosts entry corrected to `192.168.0.5`.
- [x] WSL: `memory=16GB`, `autoMemoryReclaim=gradual`.
- [x] Store apps removed: Bing News, Bing Weather, Get Help, Feedback Hub,
      Clipchamp, Office Hub, Phone Link.
- [x] Sticky Notes removed (app data under `%LOCALAPPDATA%\Packages` remains).
- [x] Nahimic app removed; service and tasks disabled.
- [x] HONOR PC Manager fully removed: services, drivers (HNOs2ECx64, OS2SOC,
      ProcessMonitor), GuardService, and `C:\Program Files\HONOR\PCManager`
      deleted. Only `HunterCampService` remains, stopped/disabled.
- [x] QiAnXin (QAX) engine removed.
- [x] Xbox: app/services/overlays removed; Xbox and GameInput services disabled;
      Game Bar, Game DVR and Game Mode turned off via policy.
      `Microsoft.XboxGameCallableUI` is a protected Windows system package and
      cannot be uninstalled (no Xbox optional capability exists on this build);
      its functions are disabled by the above.
- [x] Ubisoft Connect fully uninstalled (launcher, service, task, folders);
      uninstall entry gone.
- [x] Defender disabled: real-time, behavior, IOAV, script scanning off;
      Tamper Protection off; policy set; Defender scheduled tasks disabled.
- [x] Kept: Microsoft To Do, Photos, Camera, Media Player, Capitalism Lab.
- [x] Doubao removed: app, 4.5 GB user data, HKCU registry keys, uninstall
      entry, Start Menu/Desktop shortcuts, `aha_doctor\Doubao`, `Temp\Doubao`.
- [x] Pre-reboot autostart audit: restored the missing proxy stack tasks
      (`MihomoSplitter` SYSTEM boot task, `AliyunTunnel`, `NetDashCollector`,
      `NetDashServer`); repaired Claude's stale Run path; disabled orphan
      `OSDServer`; confirmed Tailscale, RustDesk, MWB, HypoMuxCore and the
      network services are Automatic. `AdapterMonitor` intentionally stays
      retired.

## Do next (safe)

- [ ] Reboot when convenient — finalizes Recall removal, unloads the deleted
      HONOR drivers completely, and completes the pending servicing operation.
- [ ] After reboot check:
      `Get-MpComputerStatus` shows RealTime=False, IsTamperProtected=False
      (Windows may re-enable Tamper Protection after updates; toggle it off
      again if needed).
- [ ] After reboot verify the proxy stack: elevated
      `schtasks /query /tn MihomoSplitter` shows Ready, port 7897 is
      listening, and `state\bootaudit-*.log` records the Run entry. These
      tasks run as SYSTEM, so a non-elevated Task Scheduler shows
      "access denied" rather than listing them — check elevated.
- [ ] Test HONOR Fn keys / performance mode. The HONOR EC driver was removed
      with PC Manager; if hotkeys or performance modes misbehave, that is the
      cause.
- [ ] Restart WSL when Docker/containers are idle (`wsl --shutdown`), then
      confirm `vmmemWSL` ≤ ~16 GB.
- [ ] Verify audio playback after Nahimic removal (base audio stack is still
      enabled).

## Residual notes

- [ ] `Microsoft.XboxGameCallableUI` package remains (protected, inert).
- [ ] No active antivirus (QiAnXin removed, Defender disabled) — intentional.
- [ ] Pre-existing orphan services unrelated to this cleanup: `AndrowsSvr`
      (Tencent Androws, binary missing) and `OSDServer` (binary missing) can be
      deleted if desired.
- [ ] Ubisoft game saves, if any, are in `%USERPROFILE%\Documents`.

## ERAZER side — remaining cleanup

- [ ] Quarantine corrupt SQX strategy files (move, do not delete):
      - `sp500_example_strategy\Strategy 0.8248.sqx`
      - `dow_test\Strategy 0.21(1)(3).sqx`
- [x] ERAZER rebooted 2026-10-19 14:15 (pending CBS/WU reboot cleared).
      GUI auto-started at logon; closed so the headless engine could run.
- [x] Post-reboot verified: sshd/Tailscale/RustDesk running, Tailscale direct
      path, proxy `192.168.0.2:7897` reachable, 28 GB heap at High priority.
- [x] S001 project restarted from task 1 ("Build strategies - S001 strategy")
      via scheduled task `SQX-Task1-Headless`; databank1 at 113/200.
