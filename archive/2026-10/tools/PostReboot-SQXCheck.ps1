$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$os = Get-CimInstance Win32_OperatingSystem
W ('LastBootUpTime=' + $os.LastBootUpTime + ' now=' + (Get-Date) + ' uptime=' + ((Get-Date) - $os.LastBootUpTime))
W ('CurrentUser=' + (Get-CimInstance Win32_ComputerSystem).UserName)
W ('CBS pending=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'))
W ('WU pending=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))

W '--- SERVICES ---'
Get-Service sshd, Tailscale, RustDesk, WinRM, WlanSvc, NlaSvc, Dnscache, Dhcp -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

W '--- SQX / GUI ---'
Get-Process sqcli, StrategyQuantX -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime | Format-Table -AutoSize | Out-String | Write-Output
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'sqcli|StrategyQuant' } |
    ForEach-Object { W ('  ' + $_.Name + ' pid=' + $_.ProcessId + ' cmd=' + $_.CommandLine) }

W '--- NETWORK ---'
(netsh wlan show interfaces 2>&1) | Select-String 'State|SSID|Signal' | ForEach-Object { W ('  ' + $_.Line.Trim()) }
try { W ('Proxy 127.0.0.1:7897 = ' + (Test-NetConnection 127.0.0.1 -Port 7897 -WarningAction SilentlyContinue).TcpTestSucceeded) } catch {}
try { W ('Proxy 192.168.0.2:7897 = ' + (Test-NetConnection 192.168.0.2 -Port 7897 -WarningAction SilentlyContinue).TcpTestSucceeded) } catch {}

W '--- LOGON TASKS ---'
Get-ScheduledTask -TaskName 'StartTradingAppsAtLogon','SQX145ProjectAtLogon','SQX145Project','SyncProxyWithNetwork' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- TAILSCALE ---'
if (Test-Path 'C:\Program Files\Tailscale\tailscale.exe') {
    (& 'C:\Program Files\Tailscale\tailscale.exe' status 2>&1) | Select-Object -First 4 | ForEach-Object { W ('  ' + $_) }
}
