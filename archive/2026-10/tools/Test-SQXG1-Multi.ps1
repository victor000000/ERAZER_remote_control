$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== START G1 ENGINE (temporary task enable) ==='
Enable-ScheduledTask -TaskName 'SQX145ProjectAtLogon' | Out-Null
Start-ScheduledTask -TaskName 'SQX145ProjectAtLogon'
Start-Sleep -Seconds 20
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if (-not $p) { Write-Output 'NO_SQCLI'; return }
Write-Output ('PID=' + $p.Id + ' WS_MB=' + [math]::Round($p.WorkingSet64 / 1MB))

Write-Output '=== 5-MINUTE CPU SAMPLING (10s interval) ==='
$cores = [Environment]::ProcessorCount
$samples = @()
$cpuPrev = $p.TotalProcessorTime.TotalSeconds
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 10
    $p.Refresh()
    $cpuNow = $p.TotalProcessorTime.TotalSeconds
    $pct = (($cpuNow - $cpuPrev) / 10 / $cores) * 100
    $samples += [pscustomobject]@{
        N = $i
        CPU = [math]::Round($pct, 1)
        WSMB = [math]::Round($p.WorkingSet64 / 1MB)
        PrivateMB = [math]::Round($p.PrivateMemorySize64 / 1MB)
    }
    $cpuPrev = $cpuNow
    Write-Output ('sample ' + $i + ': CPU%=' + [math]::Round($pct, 1) + ' WS_MB=' + [math]::Round($p.WorkingSet64 / 1MB))
}
$stats = $samples | Measure-Object -Property CPU -Minimum -Maximum -Average
Write-Output ('CPU stats: min=' + [math]::Round($stats.Minimum, 1) + ' max=' + [math]::Round($stats.Maximum, 1) + ' avg=' + [math]::Round($stats.Average, 1))
$wsStats = $samples | Measure-Object -Property WSMB -Minimum -Maximum -Average
Write-Output ('WS stats: min=' + $wsStats.Minimum + ' max=' + $wsStats.Maximum + ' avg=' + [math]::Round($wsStats.Average))

Write-Output '=== API ==='
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { Write-Output ('API: ' + $_.Exception.Message) }

Write-Output '=== RESTORE HEADLESS TASK DISABLED (GUI stays the reboot default) ==='
Disable-ScheduledTask -TaskName 'SQX145ProjectAtLogon' -ErrorAction SilentlyContinue | Out-Null
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon', 'StartTradingAppsAtLogon' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
