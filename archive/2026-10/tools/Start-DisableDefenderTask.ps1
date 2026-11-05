$ProgressPreference = 'SilentlyContinue'
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\Misc\Disable-ERAZERDefender.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'DisableERAZERDefender' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'DisableERAZERDefender'
Start-Sleep -Seconds 8
Get-ScheduledTask -TaskName 'DisableERAZERDefender' | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\defender-disable.txt' -ErrorAction SilentlyContinue -Tail 80
