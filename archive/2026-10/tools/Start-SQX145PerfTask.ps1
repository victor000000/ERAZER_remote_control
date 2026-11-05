$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\Vic\Desktop\Restart-SQX145-Perf.ps1 -CoreUsage 100%'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName SQX145PerfRestart -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName SQX145PerfRestart
Start-Sleep -Seconds 3
Get-ScheduledTask -TaskName SQX145PerfRestart | Select-Object TaskName, State | Format-Table -AutoSize
