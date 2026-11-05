$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$p = Get-Process sqcli -ErrorAction SilentlyContinue
if ($p) {
    W ('sqcli pid=' + $p.Id + ' started=' + $p.StartTime + ' CPU(h)=' + [math]::Round($p.TotalProcessorTime.TotalHours,2) + ' WS_MB=' + [math]::Round($p.WorkingSet64/1MB) + ' Private_MB=' + [math]::Round($p.PrivateMemorySize64/1MB))
} else {
    W 'sqcli NOT RUNNING'
    Get-Process StrategyQuantX -ErrorAction SilentlyContinue | ForEach-Object {
        W ('StrategyQuantX GUI pid=' + $_.Id + ' started=' + $_.StartTime + ' WS_MB=' + [math]::Round($_.WorkingSet64/1MB))
    }
}

W '--- PROJECT STATUS ---'
try {
    $r = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30
    W $r.Content
} catch {
    W ('API error: ' + $_.Exception.Message)
}
