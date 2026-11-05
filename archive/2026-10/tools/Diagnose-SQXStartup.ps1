$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== PROCESSES ==='
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'sqcli|java|StrategyQuant' } |
    Select-Object ProcessId, Name, CommandLine |
    Format-List | Out-String -Width 240 | Write-Output
Get-Process sqcli, java, StrategyQuantX -ErrorAction SilentlyContinue |
    Select-Object Name, Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== TASK INFO ==='
Get-ScheduledTaskInfo -TaskName 'SQX145ProjectAtLogon' -ErrorAction SilentlyContinue |
    Select-Object LastRunTime, LastTaskResult, NumberOfMissedRuns |
    Format-List | Out-String | Write-Output

Write-Output '=== CONFIG ==='
Get-Content 'C:\StrategyQuantX145\sqcli.config' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'Xm|Always' | ForEach-Object { Write-Output $_.Line.Trim() }

Write-Output '=== START LOG / ERR ==='
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\sqx145-project-start.txt' -ErrorAction SilentlyContinue -Tail 40 |
    ForEach-Object { Write-Output $_ }
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\sqx145-project-start.txt.err' -ErrorAction SilentlyContinue -Tail 40 |
    ForEach-Object { Write-Output $_ }

Write-Output '=== ENGINE LOG TAIL ==='
$l = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($l) {
    Write-Output $l.FullName
    Get-Content $l.FullName -Tail 120 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_ }
}
