$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$hideScript = 'C:\Users\Vic\ERAZER-Tools\Hide-ConsoleWindows.ps1'
$sqxScript = 'C:\Users\Vic\ERAZER-Tools\SQX\Start-SQX145-Task1.ps1'
$conhost = 'C:\Windows\System32\conhost.exe'
$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$user = 'ERAZER-6JMHAKCD\Vic'

# 1. Hide the currently visible pwsh console (pid 9456) from session 1
$hideAction = New-ScheduledTaskAction -Execute $conhost `
    -Argument ('--headless "{0}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -TargetPid 9456' -f $pwsh, $hideScript) `
    -WorkingDirectory 'C:\Users\Vic\ERAZER-Tools'
$hidePrincipal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$hideSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::FromMinutes(2)) -MultipleInstances IgnoreNew
$hideSettings.Hidden = $true
Register-ScheduledTask -TaskName 'SQX-HideConsole' -Action $hideAction -Principal $hidePrincipal -Settings $hideSettings -Force | Out-Null
Start-ScheduledTask -TaskName 'SQX-HideConsole'
Start-Sleep -Seconds 6
W ('hide task state=' + (Get-ScheduledTask -TaskName 'SQX-HideConsole').State)
$hl = 'C:\Users\Vic\ERAZER-Tools\Logs\hide-console.log'
if (Test-Path $hl) { Get-Content $hl -Tail 8 | ForEach-Object { W ('  ' + $_) } } else { W 'hide log missing' }

# 2. Re-register the SQX start task to run headless (no console) in future
$sqxAction = New-ScheduledTaskAction -Execute $conhost `
    -Argument ('--headless "{0}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}"' -f $pwsh, $sqxScript) `
    -WorkingDirectory 'C:\StrategyQuantX145'
$sqxPrincipal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$sqxSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$sqxSettings.Hidden = $true
Register-ScheduledTask -TaskName 'SQX-Task1-Headless' -Action $sqxAction -Principal $sqxPrincipal -Settings $sqxSettings -Force | Out-Null
W ('SQX task re-registered; state=' + (Get-ScheduledTask -TaskName 'SQX-Task1-Headless').State)
$t = Get-ScheduledTask -TaskName 'SQX-Task1-Headless'
foreach ($a in $t.Actions) { W ('  action: ' + $a.Execute + ' ' + $a.Arguments) }

# 3. Confirm engine still alive
$p = Get-Process sqcli -ErrorAction SilentlyContinue
W ('sqcli running=' + [bool]$p + ' pid=' + $p.Id)
try {
    $r = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 20
    W $r.Content
} catch { W ('API error: ' + $_.Exception.Message) }
