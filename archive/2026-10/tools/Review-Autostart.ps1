$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }
function Get-ExeFromCmd([string]$cmd) {
    if (-not $cmd) { return $null }
    $c = [Environment]::ExpandEnvironmentVariables($cmd.Trim())
    if ($c -match '^"([^"]+)"') { return $Matches[1] }
    return ($c -split '\s+')[0]
}

W '=== AUTOSTART REVIEW ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' ==='

W '--- AUTO SERVICES (Win32) ---'
$svcs = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.StartMode -eq 'Auto' } | Sort-Object Name
foreach ($s in $svcs) {
    $exe = Get-ExeFromCmd $s.PathName
    $exists = $null
    if ($exe -and $exe -match '^[A-Za-z]:\\') { $exists = Test-Path $exe }
    $delayed = (Get-ItemProperty ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $s.Name) -Name DelayedAutoStart -ErrorAction SilentlyContinue).DelayedAutoStart
    W ('  ' + $s.Name.PadRight(34) + ' ' + $s.State.PadRight(8) + ' binExists=' + $exists + ' delayed=' + $delayed + ' :: ' + $s.PathName)
}

W '--- AUTO SERVICES WITH MISSING BINARY ---'
$missing = $svcs | Where-Object {
    $exe = Get-ExeFromCmd $_.PathName
    ($exe -and $exe -match '^[A-Za-z]:\\' -and -not (Test-Path $exe))
}
if ($missing) { $missing | ForEach-Object { W ('  MISSING ' + $_.Name + ' -> ' + $_.PathName) } } else { W '  none' }

W '--- CRITICAL SERVICES ---'
$crit = @('Tailscale', 'RustDesk', 'MouseWithoutBordersSvc', 'WinRM', 'sshd', 'HypoMuxCore',
          'WSLService', 'CloudflareWARP', 'VMAuthdService', 'VMUSBArbService',
          'NlaSvc', 'Dnscache', 'Dhcp', 'WlanSvc', 'mpssvc', 'Audiosrv', 'WSearch', 'Spooler')
foreach ($n in $crit) {
    $s = Get-CimInstance Win32_Service -Filter ("Name='" + $n + "'") -ErrorAction SilentlyContinue
    if (-not $s) { $s = Get-CimInstance Win32_Service -Filter ("Name='" + $n.Replace("'", "''") + "'") -ErrorAction SilentlyContinue }
    $gs = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($gs) {
        $delayed = (Get-ItemProperty ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $gs.Name) -Name DelayedAutoStart -ErrorAction SilentlyContinue).DelayedAutoStart
        W ('  ' + $n.PadRight(26) + ' ' + $gs.Status.ToString().PadRight(8) + ' ' + $gs.StartType.ToString().PadRight(9) + ' delayed=' + $delayed)
    } else {
        W ('  ' + $n.PadRight(26) + ' NOT PRESENT')
    }
}

W '--- RUN KEYS ---'
$runKeys = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
             'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
             'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
             'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
foreach ($k in $runKeys) {
    $it = Get-ItemProperty $k -ErrorAction SilentlyContinue
    if ($it) {
        $it.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $exe = Get-ExeFromCmd $_.Value
            $exists = if ($exe -match '^[A-Za-z]:\\') { Test-Path $exe } else { 'n/a' }
            W ('  [' + $k.Split('\')[0] + '] ' + $_.Name + ' binExists=' + $exists + ' -> ' + $_.Value)
        }
    }
}

W '--- STARTUP FOLDERS ---'
$shell = New-Object -ComObject WScript.Shell
foreach ($d in @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
                 (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'))) {
    if (Test-Path $d) {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $target = ''
            if ($_.Extension -eq '.lnk') {
                try { $target = $shell.CreateShortcut($_.FullName).TargetPath } catch { $target = 'unreadable' }
            }
            $exists = if ($target -and $target -match '^[A-Za-z]:\\') { Test-Path $target } else { 'n/a' }
            W ('  ' + $_.Name + ' targetExists=' + $exists + ' -> ' + $target)
        }
    }
}

W '--- NON-MICROSOFT SCHEDULED TASKS ---'
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }
foreach ($t in $tasks) {
    $trig = ($t.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace 'MSFT_Task', '' }) -join ','
    foreach ($a in $t.Actions) {
        $exe = [Environment]::ExpandEnvironmentVariables($a.Execute)
        $exists = if ($exe -match '^[A-Za-z]:\\') { Test-Path $exe } else { 'n/a' }
        W ('  ' + ($t.TaskPath + $t.TaskName).PadRight(78) + ' ' + $t.State.ToString().PadRight(9) + ' trig=' + $trig + ' binExists=' + $exists + ' exe=' + $a.Execute)
    }
}

W '--- PROXY / MIHOMO ---'
$m = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mihomo|clash|hypomux' }
if ($m) { $m | ForEach-Object { W ('  process ' + $_.Name + ' pid=' + $_.Id + ' path=' + $_.Path) } } else { W '  no mihomo/clash process' }
$lst = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 7897 }
if ($lst) { $lst | ForEach-Object { W ('  port 7897 listening pid=' + $_.OwningProcess) } } else { W '  port 7897 NOT listening' }

W '--- TAILSCALE STATUS ---'
if (Test-Path 'C:\Program Files\Tailscale\tailscale.exe') {
    (& 'C:\Program Files\Tailscale\tailscale.exe' status 2>&1) | Select-Object -First 5 | ForEach-Object { W ('  ' + $_) }
}
W '=== END ==='
