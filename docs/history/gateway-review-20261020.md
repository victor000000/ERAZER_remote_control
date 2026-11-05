> Historical network review, superseded by [current connection runbook](../gateway-compatibility.md).

# ERAZER connection design with the OMR gateway

2026-10-20, Asia/Shanghai. Controller changes are live; these ERAZER source
revisions are not a claim of remote deployment.

## Compatibility findings

Mihomo still provides the controller proxy on port 7897. Its new internal
ordinary and bonded entries, 192.168.100.1:65180 and :65280, belong to the private
VM management network. ERAZER should continue using the controller's reachable
LAN proxy, not those internal endpoints. The new design does not require
replacing SSH, RustDesk or Tailscale.

Two old assumptions conflict with the controller's current state:

1. JD USB is excluded for overheating. Windows currently has no JD LAN address;
   the old 192.168.0.2 endpoint is invalid (it had also changed during DHCP churn).
   The maintained MiFi706425-5G proxy mapping is now empty, so the watcher disables
   that proxy instead of directing applications to an unavailable controller.
2. AliyunTunnel is intentionally disabled. Controller health/restore defaults
   now expect OMRGatewayBoot in its place. The controller registrar respects
   gateway mode and cannot restore the old transport as part of normal repair.

## Connection policy

- Use an independently working LAN for controller-to-ERAZER access. MiFi-1A8F
  remains a saved candidate with controller proxy 192.168.1.100:7897; the controller
  address is currently present, but the ERAZER-side path has not been verified.
  This modem's slow Internet does not require every proxied request to use that
  modem's upstream: controller Mihomo chooses the OMR route after LAN ingress.
- Retain the HypoMux SSID as a saved Windows hotspot fallback. The SSID is not
  the HypoMux dispatcher application. Hotspot availability depends on Windows
  ICS/session state and is not guaranteed before user logon.
- Tailscale has been removed from the controller by user request. Use direct
  hotspot SSH and RustDesk; preserve target-local rollback for Wi-Fi changes.
- Do not switch ERAZER Wi-Fi automatically without a tested rollback. Preserve
  saved profiles. When reachable, back up its watcher configuration, arrange a
  scheduled rollback independent of SSH/Tailscale, and retain the chosen LAN
  only if SSH and an actual HTTPS request through controller port 7897 succeed.
- Ordinary failure hysteresis and unknown-SSID proxy-off behavior remain in
  place. No MT5, SQX task, strategy or GUI/headless lifecycle changes are needed.

## Observed limits and next validation

The controller's SYSTEM boot task ran and found both OMR listeners ready without
restarting the active VM. This tests the task context and healthy-VM path; cold
boot without login has not been exercised. Inside OMR, the gateway init service
is enabled. Mihomo's boot task remains enabled.

On this review, SSH to the saved Tailscale peer timed out and the read-only LAN
discovery helper found no ERAZER SSH server. This does not establish whether
ERAZER is powered off, on another LAN, or suffering a separate network problem.
No remote Wi-Fi, watcher, firewall, task or proxy setting was changed.

Before a future deployment, inspect its actual SSID, DHCP address and deployed watcher
before applying the maintained config. The live watcher may still be the old
self-contained implementation, so copying defaults.psd1 alone is insufficient.
Follow deployment-migration.md and validate a complete bundle; preserve SQX and
MT5 settings and the independently scheduled rollback.

## Verified hotspot access at 22:05; Tailscale retired on controller

The user confirmed ERAZER is on the HypoMux hotspot. Controller WinRT reports
one client and healthy ICS at 192.168.137.1. Direct LAN ports 22 and 21118 on
192.168.137.37 were reachable. The project's `remote-hotspot.py` connected with
hostname ERAZER-6JMHAKCD; ERAZER's WinINET proxy was enabled at
192.168.137.1:7897, and a proxied Lingoda HTTPS request returned HTTP 200.
The earlier discovery failure did not establish an actual loss of ERAZER access.

Tailscale was subsequently uninstalled from the controller at the user's request.
Do not use it as a recovery dependency or reinstall it automatically. Its remote
installation was not changed. `HostKeyAlias=100.105.143.1` remains a lookup label
for the already verified SSH key, not a Tailscale transport requirement.

Controller alias `ssh erazer-hotspot` now targets 192.168.137.37 with that pinned
host identity. Maintained Target defaults and the discovery wrapper use the
hotspot address; discovery checks the pinned key before accepting a host.
Retain RustDesk direct 192.168.137.37:21118 as the alternate application channel;
it shares the hotspot and therefore does not survive loss of that radio/LAN.
An actual network switch still needs a target-local scheduled rollback.

No active ERAZER watcher, SQX or MT5 process was changed: the existing hotspot
proxy mapping already matches the gateway design. Tests passed 238/238 in both
Windows PowerShell 5.1 and PowerShell 7 for Unit/Integration suites. The full
repository check runner remains blocked by missing Windows Git; those passing
suites do not claim repository-wide lint/coverage acceptance.
