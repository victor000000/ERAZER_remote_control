$ProgressPreference = 'SilentlyContinue'
$files = @('C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config')
foreach ($f in $files) {
    if (Test-Path $f) {
        $c = Get-Content $f -Raw
        if ($c -notmatch 'AlwaysPreTouch') {
            Add-Content -Path $f -Value 'option -XX:+AlwaysPreTouch'
            Write-Output ('AlwaysPreTouch added: ' + $f)
        } else {
            Write-Output ('AlwaysPreTouch already present: ' + $f)
        }
    }
}
Select-String -Path $files -Pattern 'Xm[sx]|AlwaysPreTouch|UseParallelGC' |
    ForEach-Object { Write-Output ($_.Path + ': ' + $_.Line.Trim()) }
Write-Output '--- ENGINE ---'
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
Write-Output '--- BLUETOOTH ---'
Get-Service bthserv, BTAGService -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Write-Output '--- DEFENDER ---'
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object RealTimeProtectionEnabled, IsTamperProtected |
    Format-List | Out-String | Write-Output
