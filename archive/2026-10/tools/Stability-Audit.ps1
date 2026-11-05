$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }
$now = Get-Date
W ('=== STABILITY AUDIT ' + $env:COMPUTERNAME + ' ' + $now.ToString('yyyy-MM-dd HH:mm') + ' ===')
W '--- OS / UPTIME / RAM ---'
$os = Get-CimInstance Win32_OperatingSystem
W ('Boot=' + $os.LastBootUpTime + ' Uptime=' + ($now - $os.LastBootUpTime).ToString())
W ('RAM free=' + [math]::Round($os.FreePhysicalMemory/1KB) + 'MB / ' + [math]::Round($os.TotalVisibleMemorySize/1KB) + 'MB')

W '--- SERVICES (critical) ---'
Get-Service sshd, Tailscale, RustDesk, WinRM, WlanSvc, Dhcp, Dnscache, NlaSvc, mpssvc, WinDefend, wscsvc, SecurityHealthService -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

W '--- SCHEDULED TASKS ---'
Get-ScheduledTask -TaskName 'StartTradingAppsAtLogon','SQX145ProjectAtLogon','SQX145Project','SQX-CLI','SyncProxyWithNetwork' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- DISK / PAGE FILE ---'
Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName, MediaType, HealthStatus, @{n='SizeGB';e={[math]::Round($_.Size/1GB)}} | Format-Table -AutoSize | Out-String | Write-Output
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object AllocatedBaseSize, PeakUsage, CurrentUsage | Format-List | Out-String | Write-Output

W '--- PENDING REBOOT ---'
foreach ($r in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) {
    W ($r + ' = ' + (Test-Path $r))
}

W '--- SYSTEM ERRORS LAST 24H (top providers) ---'
$since = $now.AddHours(-24)
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue |
    Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 10 Count, Name |
    Format-Table -AutoSize | Out-String | Write-Output
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -match 'WHEA|Kernel-Power|Disk|Ntfs|Netwtw|rtw|Tcpip|Dhcp|WLAN|Service Control Manager' } |
    Select-Object -First 10 TimeCreated, ProviderName, Id, @{n='Msg';e={ if ($_.Message) { $_.Message.Substring(0,[Math]::Min(120,$_.Message.Length)) } }} |
    Format-List | Out-String -Width 200 | Write-Output

W '--- SQX ENGINE LOG ERRORS (last 200 lines) ---'
$log = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 200 -ErrorAction SilentlyContinue |
        Select-String -Pattern 'ERROR|Exception|corrupt|failed' |
        Select-Object -First 8 | ForEach-Object { W $_.Line.Substring(0,[Math]::Min(180,$_.Line.Length)) }
}

W '--- PROXY WATCHER LOG (tail) ---'
$pl = 'C:\Users\Vic\ERAZER-Tools\Proxy\proxy-watch.log'
if (Test-Path $pl) { Get-Content $pl -Tail 6 -ErrorAction SilentlyContinue | ForEach-Object { W $_ } }

W '--- TAILSCALE ---'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    (& $ts status 2>&1) | Select-Object -First 5 | ForEach-Object { W $_ }
}

W '--- NETWORK ---'
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric | Format-Table -AutoSize | Out-String | Write-Output
$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
W ('WinINET proxy=' + $p.ProxyServer + ' enabled=' + $p.ProxyEnable)
