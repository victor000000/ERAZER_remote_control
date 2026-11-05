# ERAZER Windows Stability, Network & Performance Review

**Date:** 2026-10-19  
**Target:** ERAZER D70 — Windows 11 Home 26100 (24H2), i9-13900HX (24C/32T), 32.5 GB RAM, 954 GB SSD  
**Hotspot host:** StupicVicPC — Windows 11 Home 26300, Intel Core Ultra X7 358H, Intel AX211 Wi-Fi 6E

---

## TL;DR

**Applied on the ERAZER (no SQX restart):**

- Copilot disabled: HKCU + HKLM `TurnOffWindowsCopilot=1`, taskbar button hidden, Edge sidebar/Copilot policies off; 10 running `copilotapp` processes stopped; none now running.
- CPU: High performance plan, min/max processor state 100%, core parking 100%, boost set to Aggressive, active cooling, wireless adapter power saving = Maximum Performance.
- Wi-Fi/network: adapter power-off disabled (`AllowComputerToTurnOffDevice=Disabled`), roaming = `2. Lowest`, wireless power saving max, NLA service Automatic/Running, HypoMux profile Private, proxy watcher confirmed running.
- Stability: crash dumps enabled (Automatic), Mouse Without Borders changed from **RealTime** to **AboveNormal**, MWB service running, SQX engine still **High** priority.
- **Bluetooth was NOT left disabled:** `bthserv` and `BTAGService` are running again and the MX Master 3 Mac is present/OK.
- **Defender:** re-enabled during the review with SQX/MT5 exclusions, then explicitly disabled at your request. Policy/preferences are off; the Windows Security service and tray startup are removed; the Windows Security app itself remains a protected system app.
- **Cleanup:** 20 consumer Appx packages removed (Bing News/Weather, Xbox overlays, Office Hub, Solitaire, Teams, YourPhone, Zune, Photos, Camera, Feedback Hub, Get Help, etc.), Edge auto-launch/update tasks, OneDrive setup/update and telemetry/SoftLanding tasks disabled, OEM `LISFService` disabled.
- **Full-use SQX:** both configs now use `-Xms28g -Xmx28g -XX:+AlwaysPreTouch`; page file set to 24 GB. These apply on the next engine start/reboot.

**SQX status at review time:** PID 4388, task 2 (“Build strategies - random strategies for nasdaq100”), 28 worker cores, High priority, task `SQX145Project` Running, ~6–10 GB working set.

**Biggest remaining risks:**

1. **PC-side network is the main instability source.** StupicVicPC currently has **five default routes** (`RouteMetric 0`) — WLAN to the phone hotspot plus four USB-tethered Remote NDIS adapters — and its Intel AX211 radio is simultaneously connected to the phone hotspot and broadcasting the HypoMux AP on 5 GHz. The WLAN log shows repeated HypoMux hosted-network/auth failures. Windows route selection is non-deterministic in this state.
2. **Memory headroom.** Page file was 17.2 GB allocated / 16.9 GB peak / 16.1 GB current while SQX 145 has a 28 GB heap ceiling on a 32.5 GB machine. The engine currently uses on demand (~6.4 GB working set), but the commit charge is high.
3. **Pending servicing reboot** (`CBS RebootPending=True`) after the 2026-10-18 updates.
4. **Defender real-time protection is off** (from the earlier request), with no exclusions defined. For a machine with SSH/RustDesk and credentials, this is the largest security risk.
5. **Consumer/OEM bloat and remote-service crashes:** 121 Appx packages, Edge auto-launch, OneDrive setup, OEM services (LISF/PCAppStore/Blasoul) timing out, and OpenSSH server terminated unexpectedly four times in the event log.

---

## What is healthy

| Item | State |
|---|---|
| OS | Windows 11 Home 26100, updates installed 2026-10-18 |
| CPU | i9-13900HX, 24 cores / 32 threads, high-performance plan |
| RAM | 32.5 GB total, ~16 GB free at check |
| Disk | 954 GB SSD, 777.8 GB free, health OK, wear 0, 47 °C |
| ERAZER Wi-Fi | Realtek RTL8852BE, 802.11ax, HypoMux 5 GHz, 1201/1201 Mbps, signal 100% |
| ERAZER routes | One default route only, via 192.168.137.1 |
| Proxy | WinINET + WinHTTP = 192.168.137.1:7897 with local bypass; watcher process running |
| Time | `w32time` running, synced to ntp.aliyun.com |
| Firewall | All profiles enabled |
| Events | No WHEA, Kernel-Power 41, disk or NTFS errors in the last 7 days; no minidumps |
| SQX | 145.3191, license verified, task 2 running, accepted strategies accumulating in databank |

---

## Network stability

### ERAZER side — fixed

- Wi-Fi adapter was allowed to power off (`AllowComputerToTurnOffDevice=Enabled`) — now disabled via both `Disable-NetAdapterPowerManagement` and `MSPower_DeviceEnable`.
- Roaming Aggressiveness was `4. Medium` — now `2. Lowest` (correct valid values are `1. Disable`, `2. Lowest` … `6. Highest`).
- Wireless Adapter Settings → Power Saving Mode set to **Maximum Performance** on AC.
- **NLA (Network Location Awareness) was stopped** — now Automatic and Running.
- HypoMux network profile changed from **Public** to **Private**.
- Kept: phone SSID profile manual (prevents roaming back to 荣耀WIN Turbo), proxy watcher, HypoMux 5 GHz.

### PC side — the main problem

StupicVicPC is doing too much on one radio and too many uplinks:

- **Five default routes, all `RouteMetric 0`:**

  | Interface | Next hop | Interface metric |
  |---|---|---|
  | WLAN (Intel AX211, phone hotspot) | 10.133.221.111 | 30 |
  | 以太网 2 (Remote NDIS / USB tether) | 192.168.0.1 | 25 |
  | 以太网 3 (Remote NDIS / USB tether) | 10.90.126.92 | 25 |
  | 以太网 4 (Remote NDIS / USB tether) | 192.168.0.1 | 35 |
  | 以太网 (Remote NDIS / USB tether) | 192.168.1.1 | 35 |

  Windows only really uses one default gateway; equal/low metrics make selection non-deterministic. The `Tcpip 4199` address-conflict events on both machines (192.168.1.199 and 192.168.0.3) are symptoms.

- **Same-radio STA + AP on 5 GHz:** the AX211 is connected to 荣耀WIN Turbo (10.133.221.72) **and** is the Wi-Fi Direct AP for HypoMux (`本地连接* 10`, 192.168.137.1, 5 GHz). Most adapters cannot do 5 GHz client + 5 GHz AP reliably on one radio. The WLAN operational log confirms:
  - `8010` — WLAN AutoConfig failed to stop hosted network
  - `20021` — client failed authentication in the hosted network
  - `11006` — wireless security failure on the HypoMux AP

  This is the most likely cause of the ERAZER’s intermittent network drops, not the ERAZER’s own adapter.

- **Other PC network clutter:** Speedify virtual adapter/tunnel, VMware VMnet8, Hyper-V vEthernet, NLA stopped, MIMO power save = Auto SMPS, WLAN power plan = custom “Honor Performance” with no readable sleep/USB values.

**Recommended (PC side, highest impact first):**

1. **Pick one internet uplink** (prefer the fastest stable USB tether or Ethernet). Disable the other Remote NDIS adapters or set explicit metrics (primary 10, others 50+), and remove their default gateways where possible. This alone removes most route flapping.
2. **Stop sharing the AX211 between phone client and HypoMux AP.** Either:
   - disconnect the PC from the phone hotspot and use USB-tether/Ethernet as the upstream, leaving the AX211 as the AP only; or
   - keep the phone uplink and use a separate USB Wi-Fi adapter (or a small travel router) for the HypoMux AP; or
   - wire the ERAZER to the PC with Ethernet/USB-Ethernet if physically possible.
3. Start **NLA** on the PC (`Automatic`), set the HypoMux/AP profile Private, set Intel **MIMO Power Save = No SMPS**, and disable unused virtual adapters (Speedify, VMnet8, Hyper-V vEthernet) if not needed.
4. Keep the ERAZER on the phone profile `manual` and the HypoMux 5 GHz; keep the proxy watcher.

---

## CPU and memory

### CPU — now configured for full performance

- Plan: **High performance**.
- Min/max processor state: **100% / 100%** (AC).
- Core parking minimum cores: **100**.
- Boost mode set to **Aggressive**; active cooling; wireless power-saving max.
- SQX: `coreUsage=100%`, `highPriority=true`, GPU acceleration on, memory cleanup off, ParallelGC; engine process priority **High**.
- **145 build’s own limit:** the engine logs `Adjusting used cores to: 28 from requested: 32` and uses 28 worker cores. The 144 build used 31. This appears to be a 145 internal reservation (likely its Q/SQAI/UI threads); there is no exposed setting found to reclaim the other four without disabling Q. The engine is using the maximum the 145 build allows.
- The SQX process has accumulated ~330,000 CPU-seconds; average utilization is roughly 18–20 core-equivalents over the run (generation has serial/data phases), so it is working the allowed cores hard.

### Memory — the engine uses memory on demand

- SQX CLI heap ceiling: `-Xmx28g`; current working set ~6.4 GB (it has ranged 6–11.5 GB).
- RAM: 32.5 GB total, ~16 GB free at check.
- Page file: **17,153 MB allocated / 16,928 MB peak / 16,148 MB current** — heavily used.
- The 28 GB heap is a maximum, not a preallocation. The JVM grows it as the databank/workload requires; forcing `-Xms28g`/`AlwaysPreTouch` would consume the RAM Windows and the remote/proxy tools need and increase paging.
- **Full-use configuration (per your instruction):** both configs now use `-Xms28g -Xmx28g -XX:+AlwaysPreTouch`, so the JVM commits and touches the full 28 GB on its next start. The page file is set to 24 GB so Windows and the remote tools still have backing store. This is aggressive by design; the engine’s current run keeps the old `-Xms4g` until restarted.

---

## System stability

### Applied

- Crash dumps: `CrashDumpEnabled=7` (Automatic), so future BSODs produce diagnostics. (Previously 0 = none.)
- Mouse Without Borders: two processes were at **RealTime** priority — now **AboveNormal**. RealTime user apps can starve network/audio/kernel work and are a genuine stability risk.
- NLA started, Wi-Fi power management disabled, roaming fixed, profile Private, proxy watcher confirmed.
- Copilot fully disabled and verified.

### Needs attention

| Finding | Evidence | Recommendation |
|---|---|---|
| Pending servicing reboot | `CBS RebootPending=True` after 2026-10-18 updates | Schedule a reboot when the SQX databank is saved; then restart task 2 |
| Defender | Explicitly disabled at user request after the review | Policy and preferences off; `WinDefend`/`wscsvc`/`SecurityHealthService` stopped or disabled after reboot; Windows Security app cannot be uninstalled, tray startup removed. This is a deliberate security trade-off. |
| Windows Update | `wuauserv` Manual, `UsoSvc` Running, `NoAutoRebootWithLoggedOnUsers=1` | Keep updates; use active hours/defer feature updates; never disable security updates |
| OEM services | `LISFService` repeated 7000/7009 timeouts; `PCAppStoreServiceAS` and `BlasoulPcManagerService` terminated | Identify and remove/disable the OEM updater/manager if unused |
| OpenSSH server | Service terminated unexpectedly 4× on 2026-10-18 | Update OpenSSH; review sshd logs; the 9.5 PQ warning is separate |
| RustDesk service | Failed to start once on 2026-10-18 | Keep auto-recovery; update if it recurs |
| Disabled services | WSearch, SysMain, Spooler, WerSvc, WMPNetworkSvc, Xbox*, Maps, Phone, RemoteRegistry | Mostly safe for this use; re-enable WerSvc if you want automatic crash reporting, Spooler only if you print |
| Consumer apps | 121 Appx; Bing News/Weather/Search, Xbox overlays, Solitaire, Office Hub, Teams, YourPhone, ZuneMusic, Feedback Hub, Get Help, Photos, Camera, Sticky Notes, Sound Recorder | Remove unused consumer apps; keep Store and core Settings |
| Edge / OneDrive | Edge auto-launch in HKCU Run; Edge update tasks; OneDriveSetup for default accounts; OneDrive update task | Disable Edge auto-launch and update tasks if Edge is unused; remove OneDrive if not used |
| Telemetry tasks | Consolidator, UsbCeip, DmClient*, DiskDiagnosticDataCollector, WinSAT, Application Experience tasks | Disable the telemetry/maintenance tasks; do not disable the Task Scheduler service |
| 145 Q/SQAI | 4-core reservation in the 145 engine | Optional experiment: disable Q in the GUI/console, restart, see if 31/32 cores are allowed |
| Backups | Project `.cfx`/databank live on C: | Keep periodic project/databank backups; never force-kill SQX (it corrupted strategy files earlier) |

### Do not disable

RPC, DCOM, WMI, Event Log, Task Scheduler, DHCP Client, DNS Client, WLAN AutoConfig, NLA, Firewall, Windows Update/BITS/UsoSvc, Defender, Cryptographic Services, Windows Installer, Windows Time, Storage, Security Center, **Bluetooth (`bthserv`/`BTAGService` — the MX Master 3 mouse uses it)**, audio (unless unused), and network drivers. The research consensus is that aggressive “debloat” service disabling is what breaks network stacks and update recovery.

---

## Internet guidance reviewed

- Microsoft’s own performance guidance is conservative: keep Windows/drivers updated, manage startup/background apps, keep disk space, adjust visual effects, diagnose with Task Manager, use “Best performance” power mode. It does not recommend gutting services.
- Trading-VPS guidance converges on: High Performance plan, telemetry/indexing/print spooler off if unused, Defender **exclusions** rather than disabling Defender, Windows Update active hours/no auto-restart, MT5 chart/market-watch limits, and caution against reckless service disabling.
- StrategyQuant guidance: leave at least one core for Windows, size the JVM heap to leave RAM headroom, and note that Random Generation often shows low CPU because of serial/data phases; multiple engines are the way to use more cores.
- WinUtil/debloat reviews: the “Set Services to Manual” essential tweak is the safe option; “Remove All Bloat” and disabling Edge/IPv6 are flagged risky. Create a restore point and apply only understood tweaks.
- Wi-Fi guidance: disable adapter power saving, use Maximum Performance, set MIMO No SMPS, lower roaming aggressiveness for a fixed AP, update the OEM/Intel driver.
- Hotspot guidance: same-adapter 5 GHz STA+AP is inherently limited; use a separate adapter/AP or wired link.
- Multiple default routes: set explicit interface metrics or remove the gateway from secondary adapters; Windows only uses the lowest-metric default route.

---

## Sources

- Microsoft — [Tips to improve PC performance in Windows](https://support.microsoft.com/en-us/windows/tips-to-improve-pc-performance-in-windows-b3b3ef5b-5953-fb6a-2528-4bbed82fba96)
- Microsoft Q&A — [How can I disable Copilot in Windows 11 Pro (2025)?](https://learn.microsoft.com/en-nz/answers/questions/3847406/how-can-i-disable-copilot-in-windows-11-pro-(2025))
- CyberDuo — [Disable Copilot in Windows 11 (updated June 2025)](https://www.cyberduo.com/blog/disable-copilot-in-windows-11-updated-june-2025/)
- FXVPS — [Optimizing MT5 on a VPS](https://fxvps.biz/knowledge-base/09-optimizing-mt5-on-vps/)
- FXVPS — [Antivirus on a Trading VPS: What to Run, What to Exclude](https://fxvps.biz/blog/antivirus-on-a-trading-vps/)
- DigiRDP — [Windows VPS Tuning for Forex / MT4 / MT5 Latency](https://digirdp.com/knowledgebase/windows-tuning-for-forex-trading)
- 1gbits — [How to Optimize an MT5 VPS for Algorithmic Trading](https://1gbits.com/blog/how-to-optimize-mt5-for-algorithmic-trading/)
- VM6 — [MT5 on Windows 11 VPS Setup + Optimisation Guide](https://www.vm6.co.uk/blog/2026/01/18/mt5-on-windows-11-vps-setup-optimisation-guide/)
- StrategyQuant Forum — [CPU utilization](https://strategyquant.com/forum/topic/5010-cpu-utilization/)
- Quastic — [5 tips to increase StrategyQuant performance](https://www.quastic.cz/automaticke-obchodovani/tipy-pro-zvyseni-vykonu-strategy-quant/)
- WindowsForum — [Windows 11 Performance Tweaks: WinUtil Risks and Safer Built-In Fixes](https://windowsforum.com/news/windows-11-performance-tweaks-winutil-risks-ultimate-performance-and-safer-built-in-fixes.446490/)
- Microsoft Q&A — [Network adapter Wi-Fi keeps dropping out](https://learn.microsoft.com/en-my/answers/questions/5813096/network-adaptor-wifi-keeps-dropping-out)
- Dell — [Intel Advanced Wi-Fi adapter settings](https://www.dell.com/support/kbdoc/en-au/000132395/)
- WindowsForum — [Fix random Wi-Fi drops by disabling power saving](https://windowsforum.com/tutorials/fix-random-wi-fi-drops-in-windows-10-11-by-disabling-power-saving-updating-adapter-settings.395126/)
- LaptopJudge — [Windows 11 Mobile Hotspot: Fix Tethering Drops](https://laptopjudge.com/windows-11-mobile-hotspot-fix-tethering-drops/)
- Microsoft Q&A — [Windows 11 unable to detect 5 GHz hotspot](https://learn.microsoft.com/en-ie/answers/questions/4040782/windows-11-unable-to-detect-hotspot-5ghz)
- cnblogs — [多网卡环境下的 Windows 路由优化](https://www.cnblogs.com/guyk/p/18758740)
- NinjaOne — [How to Keep a Windows 11 Laptop Awake on AC Power](https://www.ninjaone.com/blog/how-to-keep-a-windows-11-laptop-awake-on-ac/)

---

*Raw inventories: `tools/windows-review.txt` (ERAZER) and `tools/local-network-review.txt` (hotspot PC).*  
*Scripts: `tools/Apply-ERAZERStability.ps1`, `tools/Fix-ERAZERWlan.ps1`, `tools/Disable-Copilot.ps1`, `tools/Review-ERAZERWindows.ps1`, `tools/Review-LocalNetwork.ps1`.*
