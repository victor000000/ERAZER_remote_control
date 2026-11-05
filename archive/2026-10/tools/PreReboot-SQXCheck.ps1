$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- AUTO LOGON ---'
$wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
W ('AutoAdminLogon=' + $wl.AutoAdminLogon + ' DefaultUserName=' + $wl.DefaultUserName + ' PasswordPresent=' + [bool]$wl.DefaultPassword)
Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | ForEach-Object { W ('CurrentUser=' + $_.UserName) }

W '--- SQX PROCESSES ---'
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'sqcli|StrategyQuant' } |
    ForEach-Object { W ('  ' + $_.Name + ' pid=' + $_.ProcessId + ' cmd=' + $_.CommandLine) }

W '--- SQX TASKS ---'
foreach ($n in @('SQX145ProjectAtLogon', 'SQX145Project', 'StartTradingAppsAtLogon', 'SQX-CLI', 'SyncProxyWithNetwork')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        W ('  ' + $n + ' state=' + $t.State + ' user=' + $t.Principal.UserId + ' trigger=' + (($t.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','))
        foreach ($a in $t.Actions) { W ('      action: ' + $a.Execute + ' ' + $a.Arguments) }
    } else { W ('  ' + $n + ' MISSING') }
}

W '--- PENDING REBOOT ---'
W ('CBS=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'))
W ('WU=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))

W '--- NETWORK ---'
(netsh wlan show interfaces 2>&1) | Select-String 'State|SSID|Signal' | ForEach-Object { W ('  ' + $_.Line.Trim()) }
