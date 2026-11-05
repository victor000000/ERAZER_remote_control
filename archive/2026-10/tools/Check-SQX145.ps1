$ProgressPreference = 'SilentlyContinue'

Write-Output '=== PROCESSES ==='
Get-Process sqcli, StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue |
    Select-Object Id, Name, Path, StartTime | Format-Table -AutoSize

Write-Output '=== PORT 5050 ==='
Get-NetTCPConnection -State Listen -LocalPort 5050 -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize

Write-Output '=== CLI LAUNCHER VBS ==='
Get-Content 'C:\Users\Vic\Desktop\Start-SQXCLI.vbs' -ErrorAction SilentlyContinue

Write-Output '=== SQX PROCESS COMMANDS ==='
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'sqcli|StrategyQuant' } |
    Select-Object ProcessId, ParentProcessId, Name, CommandLine | Format-List

Write-Output '=== API -h ==='
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-h' -UseBasicParsing -TimeoutSec 20).Content
} catch {
    $_.Exception.Message
}

Write-Output '=== API LIST ==='
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=list' -UseBasicParsing -TimeoutSec 40).Content
} catch {
    $_.Exception.Message
}

Write-Output '=== ENGINE TAIL ==='
$log = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant\' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 80 |
        Select-String -Pattern 'licen|Verifying|ready|CLI|Project|ERROR' |
        Select-Object -Last 15 |
        ForEach-Object { $_.Line.Substring(0, [Math]::Min(240, $_.Line.Length)) }
}
