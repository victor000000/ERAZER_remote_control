# Mouse Without Borders

Both PCs use the Microsoft Garage standalone application. On **October 21,
15:53 Shanghai**, a persistent TCP connection and scheduled task result `0`
were verified on each PC. Physical cursor crossing and reboot behavior were
not exercised by those checks.

## Installed behavior

| Item | Configuration |
| --- | --- |
| Task on each PC | `ERAZER-MouseWithoutBorders-Reconnect`, SYSTEM/highest |
| Triggers | Startup and every two minutes |
| Deployed helper/state/log | `C:\ProgramData\ERAZER-Tools\MouseWithoutBorders` |
| Service | `MouseWithoutBordersSvc`, Automatic startup |
| Controller peer | `ERAZER-6JMHAKCD`: hotspot `.137.37`, LAN `192.168.1.198` |
| ERAZER peer | `STUPICVICPC`: hotspot `.137.1`, LAN `192.168.1.100` |

The abbreviated hotspot addresses above are `192.168.137.37` and
`192.168.137.1`. Use [connections](gateway-compatibility.md) to verify routes.

Healthy established connections take precedence. Otherwise the helper probes
known peer addresses on TCP 15101, corrects only the peer's short-name hosts
mapping, and waits for two disconnected checks before restarting MWB processes
and its service. Restarts are limited to once per five minutes. Offline peers
are left alone. Installation can initiate recovery immediately.

This is **known-address fallback, not DHCP discovery**. Reinstall with reviewed
addresses if leases move beyond these pairs. SQX, network adapters, firewall,
pairing key and machine layout are not changed. The installed helper/state is
administrator/SYSTEM-controlled because the task executes as SYSTEM.

## Inspect and repair

Use an elevated, hidden PowerShell context for protected task/state inspection:

```powershell
Get-ScheduledTaskInfo -TaskName 'ERAZER-MouseWithoutBorders-Reconnect'
Get-Service -Name 'MouseWithoutBordersSvc'
Get-NetTCPConnection -State Established | Where-Object {
    $_.LocalPort -in 15100,15101 -or $_.RemotePort -in 15100,15101
}
```

A non-elevated query may not see the task; that does not mean it is missing.
A stopped service can occur after launching interactive MWB processes. Inspect
established sockets, task result and `repair.log` before restarting anything.

Maintained source:
[Repair-MouseWithoutBorders.ps1](../scripts/remote/Repair-MouseWithoutBorders.ps1).
For an authorized installation/update, run elevated on the intended PC:

```powershell
# Controller: ERAZER is the peer.
powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File .\scripts\remote\Repair-MouseWithoutBorders.ps1 -PeerName ERAZER-6JMHAKCD -PeerAddress 192.168.137.37 -FallbackPeerAddress 192.168.1.198 -Install

# ERAZER: controller is the peer; use the actual transferred script path.
powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\Vic\ERAZER-Tools\Repair-MouseWithoutBorders.ps1 -PeerName STUPICVICPC -PeerAddress 192.168.137.1 -FallbackPeerAddress 192.168.1.100 -Install
```

The source has no `-WhatIf`; `-Install` changes hosts/service/task settings.
Installation copies the helper to the protected state folder. Repository edits
alone do not update either deployed copy. Windows UAC may require approval.

## Rollback and evidence

Disable/unregister only this reconnect task. Restore reviewed peer lines from
`hosts-before-*.bak` in the state folder, preserving unrelated later hosts edits.
Previous service startup was Automatic on both machines; pairing settings were
not changed. Do not restart SQX or restore removed Tailscale records.

Local evidence is in `out/mwb-repair/`: `local-install-result.json`,
`local-final-verification.json` and `erazer-final-verification.json`. Earlier
`repair-result.txt` describes the first partial repair; the later verification
supersedes its remaining controller-address limitation.
