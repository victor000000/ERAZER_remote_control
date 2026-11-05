$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== HONOR COMPONENT REMOVAL START ==='

foreach ($p in @('PCManager', 'PCManagerTray', 'HnFrontNavigator', 'ManagerUpdate', 'PCManagerMainService',
                 'MBAProcessWatcher', 'OSDListener', 'MBAUpdater', 'HNVCR', 'HnPhotoViewer',
                 'HnPCAIService', 'HNPCInferEngineService', 'HnUpdateService', 'HunterCampService',
                 'qaxdefender', 'QaxEngManager')) {
    $proc = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($proc) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue; L ('process stopped: ' + $p) }
}

function Run-Uninstaller([string]$path, [string]$arguments, [int]$timeoutSec) {
    if (-not (Test-Path $path)) { L ('uninstaller missing: ' + $path); return }
    L ('running: ' + $path + ' [' + $arguments + ']')
    try {
        $p = Start-Process -FilePath $path -ArgumentList $arguments -PassThru -WindowStyle Hidden
        if ($p.WaitForExit($timeoutSec * 1000)) {
            L ('  exit code=' + $p.ExitCode)
        } else {
            L ('  WARNING still running after ' + $timeoutSec + 's')
        }
    } catch {
        L ('  FAILED: ' + $_.Exception.Message)
    }
}

Run-Uninstaller 'C:\Program Files\HONOR\HNPCAIService\Uninstall.exe' '/S' 90
Run-Uninstaller 'C:\Program Files\HONOR\HNPCInferEngine\Uninstall.exe' '/S' 90
Run-Uninstaller 'C:\Program Files\HONOR\HunterCamp\uninst.exe' '/S' 120
Run-Uninstaller 'C:\Program Files\HONOR\PCManager\qspublic\uninstall.exe' '/S' 180

$bs = Get-CimInstance Win32_Service -Name MBAMainService -ErrorAction SilentlyContinue
if ($bs) {
    Run-Uninstaller 'C:\Program Files\HONOR\BasicService\UnInstallBasicService.exe' '-SilentUninstall' 120
} else {
    L 'BasicService already removed'
}

foreach ($s in @('HnPCAIService', 'HnPCInferEngine', 'HnUpdateService', 'HunterCampService',
                 'MBAMainService', 'QAXDefender.SDK', 'QaxEngManager')) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) { L ('service now: ' + $s + ' ' + $svc.Status + '/' + $svc.StartType) } else { L ('service gone: ' + $s) }
}
L ('PC Manager uninstall entry present: ' + [bool](Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PC Manager' -ErrorAction SilentlyContinue))
L ('PCManager folder present: ' + (Test-Path 'C:\Program Files\HONOR\PCManager'))
L '=== HONOR COMPONENT REMOVAL END ==='
