$ProgressPreference = 'SilentlyContinue'

Write-Output '=== PROCESS ==='
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, StartTime, CPU,
        @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB)}} | Format-List

Write-Output '=== API STATUS ==='
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 60).Content
} catch {
    $_.Exception.Message
}

Write-Output '=== ENGINE CORE/PROJECT LINES ==='
$log = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 500 |
        Select-String -Pattern 'Adjusting used cores|Using: .*cores|High priority|Starting project|Build strategies' |
        Select-Object -Last 12 |
        ForEach-Object { $_.Line.Substring(0, [Math]::Min(240, $_.Line.Length)) }
}

Write-Output '=== PROJECT LOG ==='
$pl = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) { Get-Content $pl.FullName -Tail 15 }

Write-Output '=== TASK ==='
Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize

Write-Output '=== SETTINGS FILES / Q KEYS ==='
Get-ChildItem 'C:\StrategyQuantX145\user\settings' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
Select-String -Path 'C:\StrategyQuantX145\user\settings\settings.xml' -Pattern 'core|priority|memory|gpu' |
    ForEach-Object { $_.Line.Trim() }

Write-Output '=== Q CONFIG FILES ==='
Get-ChildItem 'C:\StrategyQuantX145\user' -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'q|ai|sqai' -and $_.Extension -match '\.(json|xml|properties|config)$' } |
    Select-Object -First 20 FullName |
    Format-Table -AutoSize
