$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== ELEVATED TASK VERIFICATION ==='
foreach ($n in @('MihomoSplitter', 'AliyunTunnel', 'NetDashCollector', 'NetDashServer')) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        $a = ($t.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join ' | '
        L ('  ' + $n + ' state=' + $t.State + ' user=' + $t.Principal.UserId + ' runlevel=' + $t.Principal.RunLevel + ' trigger=' + (($t.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ',') + ' action=' + $a)
    } else {
        L ('  ' + $n + ' MISSING (elevated view)')
    }
}

L '--- task deletion events (141) last 2 hours ---'
try {
    $start = (Get-Date).AddHours(-2)
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-TaskScheduler/Operational'; StartTime = $start } -ErrorAction Stop |
        Where-Object { $_.Id -in 141, 142, 140, 106 }
    $count = 0
    foreach ($e in $ev) {
        $m = $e.Message -replace "`r?`n", ' '
        if ($m -match 'MihomoSplitter|AliyunTunnel|NetDashCollector|NetDashServer') {
            L ('  id=' + $e.Id + ' ' + $e.TimeCreated + ' ' + $m)
            $count++
        }
    }
    L ('  matching events=' + $count + ' total operator events=' + @($ev).Count)
} catch {
    L ('  event log query failed: ' + $_.Exception.Message)
}

L '--- non-Microsoft running processes ---'
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -notmatch '\\Windows\\' } |
    Select-Object Name, Id, Path | Sort-Object Name | ForEach-Object { L ('  ' + $_.Name + ' pid=' + $_.Id + ' ' + $_.Path) }
L '=== ELEVATED TASK VERIFICATION END ==='
