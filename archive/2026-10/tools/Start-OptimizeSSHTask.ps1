$ProgressPreference = 'SilentlyContinue'
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\Misc\Optimize-ERAZERSSH.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'OptimizeERAZERSSH' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'OptimizeERAZERSSH'
Start-Sleep -Seconds 10
Get-ScheduledTask -TaskName 'OptimizeERAZERSSH' | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\ssh-optimize.txt' -ErrorAction SilentlyContinue -Tail 90
