$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== STOP GUI ==='
Get-Process StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Get-Process StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue |
    Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== DISABLE GUI LOGON TASK ==='
Disable-ScheduledTask -TaskName 'StartTradingAppsAtLogon' -ErrorAction SilentlyContinue | Out-Null
Get-ScheduledTask -TaskName 'StartTradingAppsAtLogon' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== REMOVE ALWAYS PRETOUCH ==='
$files = @('C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config')
foreach ($f in $files) {
    if (Test-Path $f) {
        Copy-Item $f ($f + '.bak-nopretouch-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
        try {
            Get-Content $f | Where-Object { $_ -notmatch 'AlwaysPreTouch' } | Set-Content -Path $f -Encoding ASCII -ErrorAction Stop
            Write-Output ('AlwaysPreTouch removed: ' + $f)
        } catch { Write-Output ('config edit failed: ' + $f + ' - ' + $_.Exception.Message) }
    }
}
Select-String -Path $files -Pattern 'Xm[sx]|AlwaysPreTouch' |
    ForEach-Object { Write-Output ($_.Path + ': ' + $_.Line.Trim()) }

Write-Output '=== START CLI PROJECT ==='
Start-ScheduledTask -TaskName 'SQX145ProjectAtLogon'
Start-Sleep -Seconds 15
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'sqcli|StrategyQuant' } |
    Select-Object ProcessId, Name, CommandLine | Format-List | Out-String -Width 220 | Write-Output
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon', 'SQX145Project' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { Write-Output ('API: ' + $_.Exception.Message) }
