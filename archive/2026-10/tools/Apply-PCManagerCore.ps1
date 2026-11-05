$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== PC MANAGER CORE REMOVAL START ==='

# Report binary paths before touching anything
foreach ($s in @('MBAMainService', 'HnUpdateService', 'HunterCampService', 'QAXDefender.SDK', 'QaxEngManager')) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue
    if ($svc) {
        $exe = $svc.PathName
        if ($exe -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($exe -split ' ')[0] }
        L ('service ' + $s + ' binary exists=' + (Test-Path $exe) + ' path=' + $exe)
    } else {
        L ('service ' + $s + ' not found via CIM')
    }
}

# BasicService silent uninstall
$bsExe = 'C:\Program Files\HONOR\BasicService\UnInstallBasicService.exe'
if (Test-Path $bsExe) {
    L 'running BasicService uninstaller -SilentUninstall'
    $p = Start-Process -FilePath $bsExe -ArgumentList '-SilentUninstall' -PassThru -WindowStyle Hidden
    if ($p.WaitForExit(180000)) { L ('  exit code=' + $p.ExitCode) } else { L '  WARNING still running after 180s' }
} else {
    L 'BasicService uninstaller missing'
}

Start-Sleep -Seconds 3
foreach ($s in @('MBAMainService', 'HnUpdateService', 'HunterCampService', 'QAXDefender.SDK', 'QaxEngManager')) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) { L ('after: ' + $s + ' ' + $svc.Status + '/' + $svc.StartType) } else { L ('after: ' + $s + ' gone') }
}

# Delete services whose binary no longer exists
foreach ($s in @('HunterCampService', 'QAXDefender.SDK')) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue
    if ($svc) {
        $exe = $svc.PathName
        if ($exe -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($exe -split ' ')[0] }
        if (-not (Test-Path $exe)) {
            & sc.exe stop $s | Out-Null
            $r = & sc.exe delete $s 2>&1
            L ('deleted orphan service ' + $s + ': ' + ($r -join ' '))
        } else {
            L ('service binary still present, not deleting: ' + $s)
        }
    }
}

L ('PCManager folder present: ' + (Test-Path 'C:\Program Files\HONOR\PCManager'))
L ('PCManager uninstall entry present: ' + [bool](Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PC Manager' -ErrorAction SilentlyContinue))
L '=== PC MANAGER CORE REMOVAL END ==='
