# Connections and proxy

Route observations below are dated **October 30–31, 2026, Asia/Shanghai**.
Documentation review on November 7 did not retest these routes. This is the connection runbook;
the [October 20 OMR review](history/gateway-review-20261020.md) is historical.

## Known direct routes

| Route | Controller address | ERAZER address | Verification |
| --- | --- | --- | --- |
| HypoMux Windows hotspot | `192.168.137.1` | `192.168.137.37` (static) | Pinned SSH verified October 30 |
| MiFi-1A8F | `192.168.1.100` | Current DHCP lease; discover by MAC and pinned SSH | Old `.1.198` lease is stale and was assigned to another computer October 30 |

Recheck addressing after a route change; never assume
an old successful check establishes current reachability. `192.168.0.5` and
the controller's removed Tailscale address are not current access routes.

## SSH and discovery

Use `ssh erazer-hotspot hostname` from the Windows controller. The installed
identity alias retains `HostKeyAlias=100.105.143.1` and strict checking.
`erazer-ts` may still provide key/known-host options, but controller Tailscale
has been removed; that alias alone must not be used as transport.

Do not assume ERAZER still owns `192.168.1.198`. Read MiFi's current device
record using `scripts/remote/Inspect-ERAZERNetwork.py`, or let `Connect-ERAZER.ps1`
do this automatically. An `NA` router address does not establish that the PC is off.

For unknown DHCP addresses, run the maintained controller-side helper:

```powershell
powershell.exe -NoProfile -File .\Connect-ERAZER.ps1 -ForceScan hostname
```

It first checks HypoMux, then MiFi-1A8F's native device table for ERAZER's MAC
`54:ae:bc:bf:6c:37`, then scans directly attached /24 candidates with bounded
concurrency. Every candidate must pass the pinned key and
expected hostname. It changes saved SSH/hosts records only with explicit
`-UpdateTargetRecord`. Discovery is not a Wi-Fi switch or general subnet scan.

The retained WSL helper `out/s001-preservation/remote-hotspot.py` sends stdin as
hidden, noninteractive PowerShell over hotspot SSH. It is local ignored state,
not a deployed source entry point. It now delegates to maintained
`scripts/remote/erazer_transport.py`, which resolves and pins the target before
executing the supplied command once. A command timeout never triggers automatic
re-execution. `-ResolveOnly` on the controller helper emits the verified address.

A timeout alone does not mean the PC or SQX stopped. Check the other known LAN
route and controller addressing read-only. Do not switch Wi-Fi, reinstall
Tailscale or alter the hotspot merely to make a status check succeed.

## Automatic repair after an SSID change

October 30's outage had a specific cause: the WLAN adapter retained static
`192.168.137.37`, gateway/DNS `192.168.137.1`, after joining MiFi-1A8F. The
existing `Set-NetworkProfile.ps1` task ran only at sign-in, missing later switches.

The target-local **ERAZER-ConnectivityGuard** now runs as SYSTEM at startup and
every minute. Its source is `scripts/remote/Repair-ERAZERConnectivity.ps1`, deployed
under `C:\Users\Vic\ERAZER-Tools\Network`. It preserves correct HypoMux
addressing, enables DHCP and DHCP DNS on MiFi when stale static addressing is
present, reconnects a visible saved preferred/fallback profile when disconnected,
and starts SSH if stopped. It does not restart adapters, alter proxies, or touch SQX.
HypoMux is priority 1 with automatic connection; MiFi remains an automatic fallback.
Other connected SSIDs are left alone.

Inspect `connectivity-latest.json`, `connectivity-actions.jsonl`, task result and
`connectivity-errors.log` in the target Network directory. Backup-20261030 contains
the original profiles/address snapshot and a script to remove the guard. The old
sign-in proxy script is retained. Five offline address-decision cases passed,
including today's exact mismatch; live SYSTEM runs and pinned SSH were verified.
The live test captured MiFi DHCP repair from stale `192.168.137.37` to
`192.168.1.198`, then automatic HypoMux return. Pinned MiFi SSH was blocked by a
stale controller lease; after clearing that lease, a final retry found MiFi
unavailable. Do not label end-to-end MiFi SSH fully verified from this test.

This covers reachable, powered and awake ERAZER on these saved networks. Power
loss, unavailable radios/hotspots, or no shared route still require physical or
independent access; a router's stale record alone cannot distinguish these states.

### Controller stale-lease collision

A temporary diagnostic Wi-Fi join left DHCP `.1.198` on the controller's
**disconnected** WLAN adapter. When MiFi assigned that address to ERAZER, Windows
selected its own stale `/32` route, so SSH reached the controller and failed.
Rejoining the saved manual MiFi profile, releasing **WLAN only while connected**,
then disconnecting cleared the stale address. The correct route is now through
`pisen_2026_03` / `.1.100`. The controller's MiFi profile is retained as manual,
with its key encrypted by Windows; no plaintext profile file remains.

`Connect-ERAZER.ps1` detects this exact collision before testing a MiFi candidate.
It can repair a DHCP lease only on the controller's disconnected WLAN using the
saved profile, release it, and restore disconnected state. Active connections and
manual addresses are left untouched. Inspect `Get-NetIPAddress` and
`Find-NetRoute -RemoteIPAddress <candidate>` when diagnosing a refused connection;
a router record and an open port alone do not prove ERAZER's identity.

## Other access channels

RustDesk direct uses `<verified-erazer-ip>:21118`; the installed ID/relay path
is an application fallback. Direct RustDesk and SSH share the same LAN, so
neither is an independent rollback for a radio/SSID change. Keep a target-local
scheduled rollback for approved network changes.

[Mouse Without Borders](mouse-without-borders.md) is keyboard/mouse sharing,
not a shell. Its reconnect tasks know both address pairs above.

## Proxy and routing ownership

The ERAZER watcher is at
`C:\Users\Vic\ERAZER-Tools\Proxy\Sync-ProxyWithNetwork.ps1`, task
`SyncProxyWithNetwork`. Inspect the actual deployed action before editing it.

| ERAZER network | Candidate controller proxy | Required check |
| --- | --- | --- |
| HypoMux | `<gateway>:7897`, observed `192.168.137.1:7897` | Actual HTTPS through proxy from ERAZER |
| MiFi-1A8F / known shared LAN | `192.168.1.100:7897` | Confirm both current addressing and proxy reachability |
| Other SSID | Off unless explicitly configured | Do not guess a proxy address |

The controller's Mihomo project owns its upstream adapters and routing mode.
Do not infer current OMR use from `config/defaults.psd1`: it still names
`OMRGatewayBoot`, while later coordination reported Mihomo-only routing.
Reconcile that source default before any autostart restoration. Historical
adapter exclusions are not proof that the adapter remains absent today.

HypoMux here names the Windows hotspot; it does not require the retired
HypoMux dispatcher. A previous generic HTTPS success does not prove SQX's Java
process uses that proxy, nor explain a stalled vendor download queue. See
[SQX monitoring](sqx-monitoring.md) for the data-log evidence.

A network switch requires existing authorization, independent rollback, saved
profiles retained, and actual target-side SSH/proxied HTTPS validation. Keep
MT5 changes opt-in (`-UpdateMT5`); do not deploy a generic watcher over the live
one as part of diagnosis.

### 2026-10-31 connectivity and SQX exit investigation

Pinned SSH recovered on HypoMux at 05:07 Shanghai after the user reconnected ERAZER.
WLAN events also recorded the saved `MiFi706425-5G` profile. The prior guard only
handled HypoMux and MiFi-1A8F: it did not repair stale HypoMux addressing on this
third profile. The guard now also selects DHCP for MiFi706425-5G and includes it
in disconnected saved-profile recovery. This profile now permits automatic return
to a preferred network. Pure address-plan cases passed; deployment and unchanged
HypoMux SSH were checked. No deliberate live Wi-Fi switch was performed, so full
end-to-end access through the third network remains unverified. These findings do
not establish that this profile caused the entire overnight outage.

The host remained booted; the sampled sleep-event query returned no events.
SQX was absent, and its log explicitly recorded at 04:36:58: `Exit app - License
re-check failed - cannot reach the license server.` Network reachability and SQX
availability must be checked separately. HypoMux client enumeration briefly showed
zero despite subsequent successful pinned SSH: use successful pinned identity as
the authoritative reachability check. Always-on access still requires power, an
awake working OS/radio and a shared route; the guard cannot supply those remotely.


## Operator triage and verification limits (October31)

Start with a pinned hostname probe, then distinguish these layers:

| Layer | Evidence / next step |
| --- | --- |
| Radio and route | Inspect actual SSID/address/gateway and controller route. Hotspot client counts can temporarily be zero despite working SSH. |
| Host identity | Require pinned key and exact `ERAZER-6JMHAKCD` hostname. Never trust a reused DHCP address alone. |
| SSH service | The SYSTEM connectivity guard maintains automatic/running sshd. A successful SSH probe does not prove GUI/API health. |
| GUI/API | Inspect actual process, install, listener and authenticated query; startup paging can delay login. |
| Internet/license | Local SSH can work while license-server access fails. The Oct31 native exit log explicitly reported a license re-check connectivity failure. |

The guard now handles three saved SSIDs: HypoMux (static137.37), MiFi-1A8F
(DHCP), and MiFi706425-5G (DHCP). The third profile's addressing repair and
saved-profile recovery were deployed Oct31, and autoswitch back to preferred
networks enabled. Pure plan checks passed; **third-network end-to-end remote
access remains unverified**. Do not intentionally switch a working live S001
connection to test it. This does not establish the entire overnight outage cause.

Inspect target task `ERAZER-ConnectivityGuard` and its deployed script/logs under
`C:\Users\Vic\ERAZER-Tools\Network` when investigating an actual failure.
Source lives at `scripts/remote/Repair-ERAZERConnectivity.ps1`; source presence
alone does not prove deployment. Preserve pre-change copies and verify deployment
and task health separately. Do not reset adapters or alter SQX/proxy settings as
an incidental connectivity fix.

If discovery fails, retain timestamped network/failure evidence and last verified
SQX state separately. Continue bounded checks; avoid blind hotspot cycling. A
powered-off/asleep OS, unavailable radio or lack of a shared route cannot be
solved by SSH configuration alone. Guaranteed access in every physical/network
situation is not established by the current guard.
