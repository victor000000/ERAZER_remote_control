$ProgressPreference = 'SilentlyContinue'
$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\Misc\Apply-ERAZERStability.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'ApplyStabilityFixes' -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'ApplyStabilityFixes'
Start-Sleep -Seconds 8
Get-ScheduledTask -TaskName 'ApplyStabilityFixes' | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content 'C:\Users\Vic\ERAZER-Tools\Logs\stability-apply.txt' -ErrorAction SilentlyContinue -Tail 80
