$ProgressPreference = 'SilentlyContinue'
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\Misc\Fix-AllERAZER.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'FixAllERAZER' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'FixAllERAZER'
Start-Sleep -Seconds 10
Get-ScheduledTask -TaskName 'FixAllERAZER' | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\fix-all.txt' -ErrorAction SilentlyContinue -Tail 120
