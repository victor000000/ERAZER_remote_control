$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '=== REBOOT PREP ==='
$wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
W ('AutoAdminLogon=' + $wl.AutoAdminLogon + ' DefaultUserName=' + $wl.DefaultUserName + ' DefaultPasswordPresent=' + [bool]$wl.DefaultPassword)

W '--- DISABLE STRAY ONE-SHOT HEADLESS TASK ---'
Disable-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue | Out-Null
Get-ScheduledTask -TaskName 'SQX145Project','SQX145ProjectAtLogon','StartTradingAppsAtLogon','SyncProxyWithNetwork','SQX-CLI' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- LOGON TASKS ---'
foreach ($n in @('StartTradingAppsAtLogon','SyncProxyWithNetwork')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        W ('TASK ' + $n + ' state=' + $t.State)
        $t.Triggers | ForEach-Object { W ('  trigger ' + $_.CimClass.CimClassName + ' enabled=' + $_.Enabled) }
        $t.Actions | ForEach-Object { W ('  action ' + $_.Execute + ' ' + $_.Arguments) }
    }
}

W '--- MIFI PROFILE ---'
(netsh wlan show profile name="MiFi706425-5G" 2>&1) | Select-String 'Connection mode|Automatic|SSID name' |
    ForEach-Object { W $_.Line.Trim() }

W '--- SERVICES ---'
Get-Service sshd, Tailscale, RustDesk, WinRM -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

W '--- CURRENT WIFI ---'
(netsh wlan show interfaces 2>&1) | Select-String 'State|SSID|Signal' | ForEach-Object { W $_.Line.Trim() }

W '--- PENDING REBOOT ---'
W ('CBS=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'))
W ('WU=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))
