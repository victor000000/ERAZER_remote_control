$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\sqx-task1-orchestrator.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== START SQX TASK 1 ==='

# Close GUI so the headless engine can take the single instance
$gui = Get-Process StrategyQuantX -ErrorAction SilentlyContinue
if ($gui) {
    foreach ($g in $gui) {
        L ('GUI pid=' + $g.Id + ' session=' + $g.SessionId)
        try { $null = $g.CloseMainWindow() } catch { L ('CloseMainWindow failed: ' + $_.Exception.Message) }
    }
    Start-Sleep -Seconds 10
    $still = Get-Process StrategyQuantX -ErrorAction SilentlyContinue
    if ($still) { $still | Stop-Process -Force -ErrorAction SilentlyContinue; L 'GUI force-stopped (idle after reboot)'; Start-Sleep -Seconds 3 }
}
L ('GUI running=' + [bool](Get-Process StrategyQuantX -ErrorAction SilentlyContinue))

# Register a one-shot interactive task so the engine survives SSH session close
$action = New-ScheduledTaskAction -Execute 'C:\Program Files\PowerShell\7\pwsh.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Vic\ERAZER-Tools\SQX\Start-SQX145-Task1.ps1"' `
    -WorkingDirectory 'C:\StrategyQuantX145'
$principal = New-ScheduledTaskPrincipal -UserId 'ERAZER-6JMHAKCD\Vic' -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$settings.Hidden = $true
try {
    Register-ScheduledTask -TaskName 'SQX-Task1-Headless' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    L 'task SQX-Task1-Headless registered (Vic, interactive, highest)'
    Start-ScheduledTask -TaskName 'SQX-Task1-Headless'
    L 'task started'
} catch {
    L ('Register/start failed: ' + $_.Exception.Message)
}

# Wait for the API
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $r = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 10
        L 'API READY'
        L $r.Content
        $ready = $true
        break
    } catch { Start-Sleep -Seconds 4 }
}
if (-not $ready) { L 'API NOT READY after ~4 minutes' }

L ('sqcli running=' + [bool](Get-Process sqcli -ErrorAction SilentlyContinue))
Get-ScheduledTask -TaskName 'SQX-Task1-Headless' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
Get-ScheduledTaskInfo -TaskName 'SQX-Task1-Headless' -ErrorAction SilentlyContinue |
    Select-Object LastRunTime, LastTaskResult | Format-List | Out-String | Write-Output

# Confirm which task the project log shows
$pl = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) {
    L ('LOG ' + $pl.Name)
    Get-Content $pl.FullName -Tail 6 | ForEach-Object { L ('  ' + $_) }
}
L '=== END ==='
