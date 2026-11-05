$ProgressPreference = 'SilentlyContinue'
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\Misc\Fix-ERAZERDefender.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'FixERAZERDefender' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'FixERAZERDefender'
Start-Sleep -Seconds 8
Get-ScheduledTask -TaskName 'FixERAZERDefender' | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\defender-fix.txt' -ErrorAction SilentlyContinue -Tail 80
