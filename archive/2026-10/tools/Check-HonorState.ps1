$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$names = @('UnInstallBasicService', 'UninstallGuide', 'PCManager', 'PCManagerTray', 'HnFrontNavigator', 'PCManagerMainService')
foreach ($n in $names) {
    $p = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($p) {
        foreach ($x in $p) {
            Write-Output ($n + ' pid=' + $x.Id + ' title=[' + $x.MainWindowTitle + '] start=' + $x.StartTime)
        }
    } else {
        Write-Output ($n + ' not running')
    }
}
Write-Output '--- services ---'
Get-Service MBAMainService, HnUpdateService, HunterCampService, QAXDefender.SDK -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
