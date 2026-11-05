$ProgressPreference = 'SilentlyContinue'

Write-Output '=== PROJECT STATUS ==='
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 60).Content
} catch {
    $_.Exception.Message
}

Write-Output '=== PROJECT LOG ==='
$pl = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) {
    Write-Output ("FILE: " + $pl.FullName)
    Get-Content $pl.FullName -Tail 30
}

Write-Output '=== ENGINE TASK LINES ==='
$el = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($el) {
    Get-Content $el.FullName -Tail 200 |
        Select-String -Pattern 'Starting project|from task|Build strategies|random strategies|S001 strategy|Task finished' |
        Select-Object -Last 15 |
        ForEach-Object { $_.Line.Substring(0, [Math]::Min(240, $_.Line.Length)) }
}

Write-Output '=== PROCESS ==='
Get-Process sqcli -ErrorAction SilentlyContinue | Select-Object Id, StartTime, CPU | Format-List
