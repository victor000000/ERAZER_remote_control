# ERAZER Remote Control

Status: **working command-line access** from StupicVicPC to the ERAZER over
SSH, a verified RustDesk screen session, and headless SQX control through
`sqcli.exe` plus its local HTTP API.

## Topology

| Role       | Machine         | Address / identity                          |
|------------|-----------------|---------------------------------------------|
| Controller | StupicVicPC     | 192.168.0.2 (MiFi706425-5G LAN, USB tether) |
| Target     | ERAZER-6JMHAKCD | 192.168.0.5 (MiFi706425-5G Wi-Fi), user `Vic` |

- The ERAZER runs **Windows 11 Home** (build 26100), so it has no RDP host.
- Since 2026-10-19 the ERAZER joins the **MiFi706425-5G** Wi-Fi instead of the
  PC's ICS hotspot. The same MIFI also feeds the PC over USB (192.168.0.2,
  gateway 192.168.0.1), so the PC keeps a direct LAN path to the ERAZER and
  the ERAZER gains **native IPv6** (`2409:8d3c:526:df::/64`). Tailscale
  connects **directly over the LAN** (measured 9 ms), no DERP relay.
- Same-window comparison (Cloudflare 25 MB, 2026-10-19): **24.1 Mbps v4 and
  22.7 Mbps v6 on MiFi706425-5G, versus 0.67 / 0.46 Mbps on MiFi-1A8F**;
  ping v4 38 vs 34 ms, ping v6 430 vs 437 ms.
- Fallbacks, both still saved on the ERAZER: **MiFi-1A8F** (PC 192.168.1.100,
  ERAZER 192.168.1.198) and the old **HypoMux** hotspot (ERAZER .37).
  Note MiFi706425-5G and MIFI_54BA both use 192.168.0.0/24; the PC is
  dual-homed there (192.168.0.2 and 192.168.0.100), so if LAN reachability
  ever flakes, verify which tether is being used.
- Mouse Without Borders shares the physical keyboard/mouse, and a capture
  card feeds OBS on StupicVicPC.

## Channel 1 - SSH (command line, primary)

```bash
ssh erazer "hostname"
ssh erazer "dir C:\\Users\\Vic"
ssh erazer "powershell -NoProfile -Command \"Get-Process | Select -First 5\""
```

An `erazer` alias is defined in `C:\Users\victo\.ssh\config` (user `Vic`,
key `C:\Users\victo\.ssh\erazer_ed25519`). For an interactive shell run
`ssh erazer` or `.\Connect-ERAZER.ps1`.

Because the hotspot uses DHCP, the ERAZER's IP can change after it reboots,
and its hostname does not resolve from StupicVicPC unless the hosts file is
current. Use the wrapper instead of the raw alias for a guaranteed connection:

```bash
powershell -ExecutionPolicy Bypass -File .\Connect-ERAZER.ps1 hostname
```

It tries the last known IP first and, if that fails, scans this PC's local
`/24` subnets for an SSH server, verifies the hostname `ERAZER-6JMHAKCD`,
then runs the command (or opens an interactive shell).

## Reboot resilience

Configuration verified to survive a restart of the ERAZER:

- `sshd`: start type **AUTO_START**, runs as LocalSystem, starts at boot
  before any user logs in.
- Firewall: inbound allow rule for TCP 22 on **all profiles** persists.
- SSH host keys and the controller's `administrators_authorized_keys`
  entry are stored on disk.
- RustDesk: service start type **AUTO_START**; the `RustDesk Service`
  firewall rules persist; direct-IP access is enabled; a permanent password
  is stored (encrypted) in the service profile.
- The connect wrapper handles a changed IP automatically.

If a Windows servicing pass ever removes the service again, run
`tools/Repair-SSH.cmd` (a self-elevating copy sits on the ERAZER's desktop).
It recreates `sshd` when missing, sets Automatic, ensures the firewall rule,
and starts the service.

SSH is provided by the Windows OpenSSH Server optional feature
(`OpenSSH.Server~~~~0.0.1.0`). During the first reboot, Windows Update's
servicing pass deleted the feature's `sshd` service registration; it was
recreated from the inbox binary
(`C:\Windows\System32\OpenSSH\sshd.exe`) as an Automatic LocalSystem service
and verified. [`Setup-OpenSSH-On-ERAZER.ps1`](Setup-OpenSSH-On-ERAZER.ps1)
installs the standalone Win32-OpenSSH MSI (via a GitHub mirror with SHA-256
verification) as an alternative path and likewise installs the controller's
key.

**Limitations of the SSH channel**

- Commands run in a non-interactive logon session, so GUI programs started
  this way do not appear on the ERAZER's desktop. Use the desktop (physically
  or via RustDesk) to launch visible applications; use SSH for commands,
  files, services, and automation.
- On this machine the SSH session carries a high-integrity administrator
  token (verified with `whoami /groups`), so service and system changes can
  be made directly over SSH.
- **Processes started directly from an SSH command are killed when that SSH
  session ends.** Long-running work must be launched through Task Scheduler
  (the proxy watcher and SQX CLI tasks below follow this rule).

## Channel 2 - RustDesk (screen)

RustDesk 1.5.0 is installed on both machines. The session was verified over
direct IP:

- ERAZER direct server: `<erazer-ip>:21118` (`direct-server = 'Y'`).
- RustDesk IDs and the permanent/one-time passwords are **not stored in this
  repository**; read them from the RustDesk app on each machine (the current
  values are also kept in the git-ignored `credentials.local.txt`).

Note: RustDesk's keyboard grab filters synthetic (injected) input on the
controller side, so automated keystrokes/clicks do not reach the remote.
Operate the session with the **physical** keyboard and mouse. RustDesk 1.5
also advertises a remote terminal feature (`terminal: true`) in the session
toolbar.

For password-less connection startup on the controller, the
`allow-deep-link-password` option is enabled and a desktop shortcut opens
`rustdesk://<erazer-ip>?password=<permanent-password>`, which authenticates
without a prompt.

## Channel 3 - Mouse Without Borders / capture card

Used for the initial setup: MWB mirrors the physical keyboard/mouse between
the machines, and the UGREEN capture card lets StupicVicPC display the ERAZER
through OBS. Neither provides a command line, but they remain useful for
GUI work on the ERAZER.

## SQX templates and headless control

The ERAZER's full-license install is `C:\StrategyQuantX144`.

- Strategy templates live in
  `C:\StrategyQuantX144\user\settings\StrategyTemplates`.
  The S001 templates copied from StupicVicPC are
  `AItemplate_Breakout_SP500_template.sqx`,
  `S001_random_group_template_20260925.sqx`, and
  `S001_entry_revised_template.sqx`.
- The **first Build task** (`Build-Task2.xml`, "Build strategies - S001
  strategy") uses `S001_entry_revised_template.sqx`. The other build/retest
  tasks keep their existing templates (random-group / SP500).
- The "Save to files" output folder is
  `C:\StrategyQuantX144\user\S001_sys_parameters`.
- Project: `C:\StrategyQuantX144\user\projects\S001_reproduce_project\project.cfx`.
  Its task XMLs store template paths as absolute paths; they were rewritten
  from the old `C:\Users\victo\Documents\quantatative_analysis\...` prefix to
  the two paths above. Backups are kept as `project.cfx.bak-*`.

**Do not edit the project `.cfx` archive in place.** A
`ZipArchive` in-place update produced an archive that .NET could read but
SQX rejected with "Config file ... is corrupted". Use
[`tools/Rebuild-SQXProject.ps1`](tools/Rebuild-SQXProject.ps1), which extracts
the original archive, applies byte-preserving path replacements, and writes a
fresh ZIP. The rebuilt project then loads cleanly.

### CLI

`C:\StrategyQuantX144\sqcli.exe` (build 144.2953) supports non-interactive
commands:

```text
sqcli.exe -project action=list
sqcli.exe -project action=start name=S001_reproduce_project
sqcli.exe -project action=status name=S001_reproduce_project
sqcli.exe -project action=stop name=S001_reproduce_project
sqcli.exe -project action=pause|resume name=<project>
sqcli.exe -project action=startOnlyTask name=<project> task=<n>
sqcli.exe -project action=startFromTask name=<project> task=<n>
sqcli.exe -project action=loadconfig|saveconfig name=<project> file=<cfx>
```

Other command groups are `-databank` (list/count/save/load/delete/clear/
create/remove/synctofiles/syncfromfiles/copy/move/export), `-symbol`,
`-instrument`, and `-data`. The full help text from the running engine is in
[`docs/sqx-cli-help.txt`](docs/sqx-cli-help.txt).

### HTTP API

While a CLI engine is running it serves commands on port 5050:

```text
http://localhost:5050/call?cmd=<command>
```

Encode spaces as `%20`; keep `=` literal (a fully percent-encoded `%3D` is
rejected with "Missing parameter 'action'").

Example (from the ERAZER):

```text
curl "http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project"
```

### Single-instance rule

SQX allows **one instance per installation folder**. The GUI and the CLI
cannot run at the same time:

- With the GUI running, `sqcli.exe` exits with "another instance ... is
  running".
- With the GUI running, the 5050 endpoint returns `Error: CLI not ready.`
- The API/CLI control the **engine** (projects/tasks/databanks/symbols/
  instruments/data), not the Electron window. GUI-only actions would need
  Windows UI automation inside session 1, which is separate from SQX.
- Closing the GUI: SQX saves databanks and then shows an **"Are you sure you
  want to exit?"** confirmation on the ERAZER desktop. `Close-SQX.ps1` sends
  `WM_CLOSE`, which starts the save and raises this dialog, but the dialog
  must be confirmed on the ERAZER itself; SSH/session-0 automation cannot
  see or click it. Force-stop only after databank writes have been idle.

### Control helper

`tools/Control-SQX.ps1` (deployed to the ERAZER desktop with
`Control-SQX.cmd`) wraps the API:

```powershell
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action status
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action start
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action stop
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action start-task -Task 2
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action gui
pwsh -File C:\Users\Vic\Desktop\Control-SQX.ps1 -Action headless
```

`-Action headless` stops the GUI, starts the on-demand `SQX-CLI` scheduled
task (which launches `sqcli.exe` hidden through `Start-SQXCLI.vbs`), and
waits for port 5050. `-Action gui` stops the project, exits the CLI engine,
and starts `StartTradingAppsAtLogon` (SQX GUI + MT5). The `SQX-CLI` task has
no trigger, so a reboot returns to the GUI unless the task is started again.

## Proxy automation (HypoMux)

`tools/Sync-ProxyWithNetwork.ps1` (v2) is deployed to the ERAZER desktop as
`Sync-ProxyWithNetwork.ps1` with a `.vbs` hidden launcher and is run by the
`SyncProxyWithNetwork` scheduled task at logon (Interactive, **RunLevel
Highest**, unlimited runtime).

Behavior every 30 seconds:

- SSID `HypoMux` with a default gateway: enable the system proxy
  (`<gateway>:7897`) in WinINET, WinHTTP, and
  `C:\MetaTrader 5 IC Markets Global\Config\common.ini`, then refresh
  WinINET so running apps see it.
- SSID `MiFi706425-5G` (current, native-IPv6 MIFI LAN since 2026-10-19):
  enable the same proxy via the controller's LAN address `192.168.0.2:7897`.
- SSID `MiFi-1A8F` (fallback MIFI LAN): enable the same proxy via the
  controller's LAN address `192.168.1.100:7897` instead of the gateway.
- Any other SSID, or a proxy SSID without a gateway: disable the proxy. Never
  enables the proxy with an empty server.
- Probes the proxy with a 700 ms TCP connect. Three consecutive failures
  disable the proxy so direct ICS internet still works; other failures keep
  the current state to avoid flapping while Wi-Fi associates.
- MT5 is closed gracefully **before** `common.ini` is edited and restarted
  afterward only if it was running. The INI is read/written as Latin-1 so
  non-ASCII bytes are preserved byte-for-byte.
- WinHTTP changes need elevation; the task now runs Highest, and failures are
  written to `C:\Users\Vic\Desktop\proxy-watch.log`.
- A named mutex prevents duplicate watchers; the log rotates at 1 MB.

Network measurements from the ERAZER:

- Direct access to `datafeed.dukascopy.com` is blocked (curl exit 28);
  through the proxy it answers, but returns HTTP **429** under SQX's parallel
  download load.
- `cdn005.strategyquantcdn.com` answers directly in ~0.35 s and through the
  proxy in ~7.7 s. No bypass rule was added; the proxy remains enabled on
  HypoMux.

## Files

| File | Purpose |
|------|---------|
| `Setup-OpenSSH-On-ERAZER.ps1` | One-time SSH server + key installation on the ERAZER |
| `Connect-ERAZER.ps1` | SSH wrapper (interactive or single command) |
| `Setup-ERAZER-Remote.ps1` | Earlier RDP/RustDesk setup script (RDP path not applicable to Home) |
| `Restart-RustDeskTray.ps1` | Closes the RustDesk window, keeping it in the tray |
| `Remote-Input.ps1`, `Probe.ps1`, `Mouse-Test.ps1` | Diagnostics used while testing RustDesk input |
| `tools/Sync-ProxyWithNetwork.ps1` | Network-aware proxy watcher (WinINET, WinHTTP, MT5) |
| `tools/Rebuild-SQXProject.ps1` | Rewrites SQX project paths by rebuilding the `.cfx` ZIP |
| `tools/Control-SQX.ps1`, `.cmd` | Start/stop/status projects through the SQX HTTP API; switch GUI/headless |
| `tools/Start-SQXCLI.vbs` | Hidden launcher used by the `SQX-CLI` scheduled task |
| `tools/Close-SQX.ps1` | Graceful close helper for the Electron UI (falls back to process stop) |
| `docs/sqx-cli-help.txt` | Full `sqcli.exe -h` output captured from build 144.2953 |

## Security notes

- SSH uses public-key authentication only; no password is stored anywhere.
- `sshd` listens on the hotspot LAN only. Do not port-forward it to the
  internet.
- The private key stays in `C:\Users\victo\.ssh\` and is never committed.
- The Mouse Without Borders security key and RustDesk passwords are not
  stored in this repository; the local `credentials.local.txt` is
  git-ignored.
- The SQX HTTP API on port 5050 has no authentication and binds
  `0.0.0.0`; keep it on the trusted HypoMux LAN and do not expose it.
