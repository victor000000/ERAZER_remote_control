$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- EXPECTED TASKS ---'
foreach ($n in @('MihomoSplitter', 'AliyunTunnel', 'NetDashCollector', 'NetDashServer', 'AdapterMonitor',
                 'AutoLearnRulesLimited', 'BootAudit', 'BootWatch', 'MobileHotspot', 'MobileHotspotStatus', 'NetworkStatus')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        W ('  ' + $n.PadRight(24) + ' present state=' + $t.State + ' user=' + $t.Principal.UserId + ' trigger=' + (($t.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','))
    } else {
        W ('  ' + $n.PadRight(24) + ' MISSING')
    }
}

W '--- EXPECTED SCRIPTS ---'
foreach ($p in @('C:\Users\victo\mihomo\runtime\mihomo-supervisor.ps1',
                 'C:\Users\victo\mihomo\src\proxy\AliyunTunnel.ps1',
                 'C:\Users\victo\mihomo\src\dashboard\Collector.ps1',
                 'C:\Users\victo\mihomo\src\dashboard\Server.ps1',
                 'C:\Users\victo\mihomo\src\proxy\Watch-Adapters.ps1',
                 'C:\Users\victo\mihomo\src\proxy\Update-AutoLearnRules.ps1',
                 'C:\Users\victo\mihomo\src\monitor\BootAudit.ps1',
                 'C:\Users\victo\mihomo\src\monitor\Watch-Boot.ps1',
                 'C:\Users\victo\mihomo\src\monitor\StatusWindow.ps1',
                 'C:\Users\victo\mihomo\src\hotspot\Hotspot.ps1')) {
    W ('  ' + $p + ' exists=' + (Test-Path $p))
}

W '--- SMARTDNS ---'
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'smartdns' } | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-Process -Name 'smartdns*' -ErrorAction SilentlyContinue | Select-Object Name, Id, Path | Format-Table -AutoSize | Out-String | Write-Output
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'SmartDNS|smartdns' } |
    Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output

W '--- SSH TUNNEL PROCESSES ---'
Get-Process -Name 'ssh' -ErrorAction SilentlyContinue | Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'AliyunTunnel|ssh .*1080|socks' } |
    Select-Object ProcessId, Name, CommandLine | Format-List | Out-String -Width 240 | Write-Output

W '--- ADAPTER MONITOR REGISTRAR HEAD ---'
$f = 'C:\Users\victo\mihomo\src\setup\Register-AdapterMonitorTask.ps1'
if (Test-Path $f) { Get-Content $f -TotalCount 30 | ForEach-Object { W ('  ' + $_) } }
