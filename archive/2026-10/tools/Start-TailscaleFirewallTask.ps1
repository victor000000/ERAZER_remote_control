$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

$taskName = 'TailscaleFirewallAllProfiles'
$cmd      = Join-Path $PSScriptRoot 'Add-TailscaleFirewall-All.cmd'
$outFile  = Join-Path (Split-Path -Parent $PSScriptRoot) 'out\ts-fw.txt'

if (-not (Test-Path -LiteralPath $cmd)) { Write-Error "missing $cmd"; exit 1 }

$action = New-ScheduledTaskAction -Execute $cmd
# Placeholder trigger only; the task is started immediately and removed below,
# so it can never fire again on its own.
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5))
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 6
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State | Format-Table -AutoSize
Get-Content -LiteralPath $outFile -ErrorAction SilentlyContinue -Tail 30
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Write-Output 'task removed (one-shot helper)'
