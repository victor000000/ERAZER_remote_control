$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- RESTORED TASKS: ACTION TARGETS ---'
foreach ($n in @('MihomoSplitter', 'AliyunTunnel', 'NetDashCollector', 'NetDashServer')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        foreach ($a in $t.Actions) {
            $line = $a.Execute + ' ' + $a.Arguments
            W ('  ' + $n + ' [' + $t.State + '] ' + $line)
            if ($line -match '-File\s+"?([^"]+\.ps1)') { W ('    script exists=' + (Test-Path $Matches[1])) }
        }
    } else { W ('  ' + $n + ' MISSING') }
}

W '--- CRITICAL AUTOSTART ---'
foreach ($n in @('Tailscale', 'RustDesk', 'MouseWithoutBordersSvc', 'HypoMuxCore', 'WlanSvc', 'NlaSvc', 'Dnscache', 'Dhcp')) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { W ('  ' + $n.PadRight(24) + ' ' + $s.Status + '/' + $s.StartType) } else { W ('  ' + $n + ' NOT PRESENT') }
}
$hyp = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).HypoMux
W ('  HypoMux Run=' + $hyp)
$appr = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue
W ('  HypoMux StartupApproved=' + [BitConverter]::ToString($appr.HypoMux))
$cl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).Claude
W ('  Claude Run=' + $cl)

W '--- PROXY NOW ---'
$lst = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 7897 }
if ($lst) { W ('  port 7897 listening pid=' + (($lst | Select-Object -First 1).OwningProcess)) } else { W '  port 7897 NOT listening' }
W ('  mihomo process=' + @(Get-Process mihomo -ErrorAction SilentlyContinue).Count)

W '--- REFS TO REMOVED SOFTWARE IN AUTOSTART ---'
$hits = @()
foreach ($k in @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Value -match 'HONOR|PCManager|Nahimic|Ubisoft|qianxin|Xbox' } |
        ForEach-Object { $hits += ($k + ' ' + $_.Name + '=' + $_.Value) }
}
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    foreach ($a in $t.Actions) {
        if (($a.Execute + ' ' + $a.Arguments) -match 'HONOR|PCManager|Nahimic|Ubisoft|qianxin') {
            $hits += ('task ' + $t.TaskPath + $t.TaskName + ' -> ' + $a.Execute + ' ' + $a.Arguments)
        }
    }
}
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|PCManager|Nahimic|Ubisoft|qianxin' } |
    ForEach-Object { $hits += ('service ' + $_.Name + ' -> ' + $_.PathName) }
if ($hits) { $hits | ForEach-Object { W ('  ' + $_) } } else { W '  none' }
