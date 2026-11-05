$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$os = Get-CimInstance Win32_OperatingSystem
W ('OS boot: ' + $os.LastBootUpTime + ' | uptime ' + ((Get-Date) - $os.LastBootUpTime))
W '--- SQX PROCESS ---'
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}}, StartTime |
    Format-List | Out-String | Write-Output
W '--- TASKS ---'
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon', 'SQX145Project', 'SQX-CLI', 'StartTradingAppsAtLogon' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
W '--- API ---'
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { W ('API: ' + $_.Exception.Message) }
W '--- PAGE FILE ---'
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
    Select-Object Name, AllocatedBaseSize, PeakUsage, CurrentUsage | Format-List | Out-String | Write-Output
Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue |
    Select-Object Name, InitialSize, MaximumSize | Format-List | Out-String | Write-Output
W '--- HEAP CONFIG ---'
Select-String -Path 'C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config' -Pattern 'Xm[sx]|AlwaysPreTouch' |
    ForEach-Object { W ($_.Path + ': ' + $_.Line.Trim()) }
W '--- DEFENDER / SECURITY ---'
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, BehaviorMonitorEnabled,
        IoavProtectionEnabled, AntispywareEnabled, IsTamperProtected |
    Format-List | Out-String | Write-Output
Get-Service WinDefend, wscsvc, SecurityHealthService -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
W '--- BLUETOOTH / SSH / WINRM ---'
Get-Service bthserv, BTAGService, sshd, WinRM -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match 'MX|Mouse|Bluetooth Adapter' } |
    Select-Object Status, FriendlyName | Format-Table -AutoSize | Out-String | Write-Output
(& 'C:\Windows\System32\OpenSSH\ssh.exe' -V 2>&1) | ForEach-Object { W $_ }
W '--- SSH CONFIG ---'
Get-Content 'C:\ProgramData\ssh\sshd_config' | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { W $_ }
