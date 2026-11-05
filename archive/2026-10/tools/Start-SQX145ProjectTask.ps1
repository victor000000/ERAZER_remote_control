$ProgressPreference = 'SilentlyContinue'

Stop-ScheduledTask -TaskName SQX-CLI -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskName SQX145ListTest -ErrorAction SilentlyContinue
Get-Process sqcli -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$action = New-ScheduledTaskAction -Execute 'C:\Users\Vic\ERAZER-Tools\SQX\Start-SQX145-Project.cmd'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(1))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'Vic' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName SQX145Project -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName SQX145Project
Start-Sleep -Seconds 3
Get-ScheduledTask -TaskName SQX145Project | Select-Object TaskName, State | Format-Table -AutoSize
