$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

function Measure-SQX([string]$label) {
    Write-Output ('=== MEASURE ' + $label + ' ===')
    $p = Get-Process sqcli -ErrorAction SilentlyContinue
    if (-not $p) { Write-Output 'NO_SQCLI'; return }
    $cpu1 = $p.TotalProcessorTime.TotalSeconds
    $ws1 = $p.WorkingSet64
    $priv1 = $p.PrivateMemorySize64
    Start-Sleep -Seconds 60
    $p.Refresh()
    $cpu2 = $p.TotalProcessorTime.TotalSeconds
    $ws2 = $p.WorkingSet64
    $priv2 = $p.PrivateMemorySize64
    $pct = (($cpu2 - $cpu1) / 60 / [Environment]::ProcessorCount) * 100
    Write-Output ('CPU%=' + [math]::Round($pct, 1) + ' WS_MB=' + [math]::Round($ws2 / 1MB) + ' Private_MB=' + [math]::Round($priv2 / 1MB))
    try {
        (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
    } catch { Write-Output ('API: ' + $_.Exception.Message) }
}

Measure-SQX 'CURRENT (28g ParallelGC AlwaysPreTouch)'
