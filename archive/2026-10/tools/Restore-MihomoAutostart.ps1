$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== RESTORE MIHOMO AUTOSTART TASKS ==='
try {
    $out = & 'C:\Users\victo\mihomo\src\setup\Register-AllTasks.ps1' 2>&1
    foreach ($line in $out) { L ('  ' + $line) }
    L ('  registrar exit ok')
} catch {
    L ('  registrar FAILED: ' + $_.Exception.Message)
}

Start-Sleep -Seconds 2
foreach ($n in @('MihomoSplitter', 'AliyunTunnel', 'NetDashCollector', 'NetDashServer',
                 'MobileHotspot', 'MobileHotspotStatus', 'NetworkStatus', 'BootAudit', 'BootWatch', 'AutoLearnRulesLimited')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        $tr = ($t.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','
        L ('  ' + $n.PadRight(24) + ' state=' + $t.State + ' user=' + $t.Principal.UserId + ' trigger=' + $tr)
    } else {
        L ('  ' + $n.PadRight(24) + ' STILL MISSING')
    }
}

# Orphan OSD service with a missing binary: stop it from being attempted at boot.
$osd = Get-Service OSDServer -ErrorAction SilentlyContinue
if ($osd) {
    Set-Service OSDServer -StartupType Disabled -ErrorAction SilentlyContinue
    L ('OSDServer -> ' + (Get-Service OSDServer).StartType)
}
L '=== MIHOMO AUTOSTART RESTORE END ==='
