$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== STOP PROJECT / SAVE DATABANK ==='
try {
    $r = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=stop%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30
    Write-Output $r.Content
} catch { Write-Output ('stop API: ' + $_.Exception.Message) }
Start-Sleep -Seconds 6
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== LOGON TASK: S001 FROM TASK 2 ==='
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\SQX\Start-SQX145-Project.cmd'
$trigger = New-ScheduledTaskTrigger -AtLogOn -User 'Vic'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'SQX145ProjectAtLogon' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Disable-ScheduledTask -TaskName 'SQX-CLI' -ErrorAction SilentlyContinue | Out-Null
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon', 'SQX-CLI', 'SQX145Project', 'StartTradingAppsAtLogon' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== REBOOT ==='
Write-Output ('rebooting at ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Restart-Computer -Force
