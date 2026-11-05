$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('=== BOOT CHAIN ' + $env:COMPUTERNAME + ' ===')
W '--- SERVICES ---'
Get-Service sshd, Tailscale, RustDesk, WinRM, WlanSvc, Dhcp, Dnscache, NlaSvc, mpssvc -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

W '--- TASK TRIGGERS/ACTIONS ---'
foreach ($n in @('StartTradingAppsAtLogon','SyncProxyWithNetwork','SQX145ProjectAtLogon','SQX-CLI','SQX145Project')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        W ('TASK ' + $n + ' state=' + $t.State)
        $t.Triggers | ForEach-Object {
            W ('  trigger: ' + $_.CimClass.CimClassName + ' enabled=' + $_.Enabled)
        }
        $t.Actions | ForEach-Object { W ('  action: ' + $_.Execute + ' ' + $_.Arguments) }
        $t.Principal | ForEach-Object { W ('  principal: ' + $_.UserId + ' logon=' + $_.LogonType + ' runlevel=' + $_.RunLevel) }
    } else { W ('TASK ' + $n + ' missing') }
}

W '--- AUTO LOGON ---'
$wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
W ('AutoAdminLogon=' + $wl.AutoAdminLogon + ' DefaultUserName=' + $wl.DefaultUserName)
Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | ForEach-Object { W ('CurrentUser=' + $_.UserName) }

W '--- WLAN PROFILES ---'
(netsh wlan show profiles) 2>&1 | Select-String 'All User Profile' | ForEach-Object { W $_.Line.Trim() }

W '--- PROXY WATCHER NOW ---'
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'Sync-ProxyWithNetwork' } |
    Select-Object ProcessId, Name | Format-Table -AutoSize | Out-String | Write-Output

W '--- TAILSCALE ---'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) { (& $ts status 2>&1) | Select-Object -First 5 | ForEach-Object { W $_ } }
