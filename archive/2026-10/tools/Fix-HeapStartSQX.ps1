$ProgressPreference = 'SilentlyContinue'
$files = @('C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config')
foreach ($f in $files) {
    if (Test-Path $f) {
        Copy-Item $f ($f + '.bak-nopretouch-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
        Get-Content $f | Where-Object { $_ -notmatch 'AlwaysPreTouch' } | Set-Content -Path $f -Encoding ASCII
        Write-Output ('removed AlwaysPreTouch: ' + $f)
    }
}
Select-String -Path $files -Pattern 'Xm[sx]|AlwaysPreTouch' |
    ForEach-Object { Write-Output ($_.Path + ': ' + $_.Line.Trim()) }

Write-Output '--- start task ---'
Start-ScheduledTask -TaskName 'SQX145ProjectAtLogon'
Start-Sleep -Seconds 15
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { Write-Output ('API: ' + $_.Exception.Message) }
