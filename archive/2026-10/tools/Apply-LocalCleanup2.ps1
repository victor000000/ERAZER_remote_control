# Local cleanup phase 2 - requested by user 2026-10-19.
# Removes: listed Store apps, Nahimic app, HONOR AI/HunterCamp/QAX components,
# Ubisoft background service/task; disables HONOR services and Defender.
# Keeps: Photos, Camera, Xbox stack, Microsoft To Do, Zune Music, Capitalism Lab,
# HONOR Control Center, audio drivers, all other user software.
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== ELEVATED CLEANUP PHASE 2 START ==='

# ---------- 1. Store apps requested for removal ----------
$remove = @(
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.GetHelp',
    'Microsoft.WindowsFeedbackHub',
    'Clipchamp.Clipchamp',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.YourPhone'
)
foreach ($n in $remove) {
    $pkg = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
    if ($pkg) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            L ('appx removed: ' + $n)
        } catch {
            L ('appx remove FAILED: ' + $n + ' - ' + $_.Exception.Message)
        }
    } else {
        L ('appx not present: ' + $n)
    }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $n }
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        L ('provisioned package removed: ' + $n)
    }
}

# ---------- 2. Nahimic ----------
foreach ($t in @('NahimicTask32', 'NahimicTask64')) {
    if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
        Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        L ('task disabled: ' + $t)
    }
}
Stop-Service NahimicService -Force -ErrorAction SilentlyContinue
Set-Service NahimicService -StartupType Disabled -ErrorAction SilentlyContinue
L ('NahimicService -> ' + (Get-Service NahimicService -ErrorAction SilentlyContinue).Status + '/' + (Get-Service NahimicService -ErrorAction SilentlyContinue).StartType)
Get-Process -Name 'NahimicAPO4Volume', 'NahimicSvc32', 'NahimicSvc64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$nah = Get-AppxPackage -Name 'A-Volute.Nahimic' -ErrorAction SilentlyContinue
if ($nah) {
    try {
        Remove-AppxPackage -Package $nah.PackageFullName -ErrorAction Stop
        L 'appx removed: A-Volute.Nahimic'
    } catch {
        L ('appx remove FAILED: A-Volute.Nahimic - ' + $_.Exception.Message)
    }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'A-Volute.Nahimic' }
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        L 'provisioned package removed: A-Volute.Nahimic'
    }
} else {
    L 'A-Volute.Nahimic appx not present'
}

# ---------- 3. HONOR: stop processes, disable services, uninstall components ----------
$honorProcs = @('PCManager', 'PCManagerTray', 'HnFrontNavigator', 'ManagerUpdate', 'PCManagerMainService',
                'MBAProcessWatcher', 'OSDListener', 'MBAUpdater', 'MBATestMessageClient', 'HiCenter',
                'HNVCR', 'HnPhotoViewer', 'HnPCAIService', 'HNPCInferEngineService', 'HnUpdateService',
                'HunterCampService', 'qaxdefender', 'QaxEngManager')
foreach ($p in $honorProcs) {
    $proc = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        L ('process stopped: ' + $p)
    }
}

$honorSvcs = @('HnPCAIService', 'HnPCInferEngine', 'HnUpdateService', 'HunterCampService',
               'MBAMainService', 'QAXDefender.SDK', 'QaxEngManager')
foreach ($s in $honorSvcs) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        $now = Get-Service -Name $s -ErrorAction SilentlyContinue
        L ('service ' + $s + ' -> ' + $now.Status + '/' + $now.StartType)
    }
}

function Run-Uninstaller([string]$path, [string]$args, [int]$timeoutSec) {
    if (-not (Test-Path $path)) { L ('uninstaller missing: ' + $path); return }
    L ('running: ' + $path + ' ' + $args)
    try {
        $p = Start-Process -FilePath $path -ArgumentList $args -PassThru -WindowStyle Hidden
        if ($p.WaitForExit($timeoutSec * 1000)) {
            L ('  exit code=' + $p.ExitCode + ' (' + $path + ')')
        } else {
            L ('  WARNING still running after ' + $timeoutSec + 's: ' + $path)
        }
    } catch {
        L ('  FAILED to start ' + $path + ': ' + $_.Exception.Message)
    }
}

Run-Uninstaller 'C:\Program Files\HONOR\HNPCAIService\Uninstall.exe' '/S' 90
Run-Uninstaller 'C:\Program Files\HONOR\HNPCInferEngine\Uninstall.exe' '/S' 90
Run-Uninstaller 'C:\Program Files\HONOR\HunterCamp\uninst.exe' '/S' 120
Run-Uninstaller 'C:\Program Files\HONOR\PCManager\qspublic\uninstall.exe' '/S' 180
Run-Uninstaller 'C:\Program Files\HONOR\BasicService\UnInstallBasicService.exe' '-SilentUninstall' 120

foreach ($s in $honorSvcs) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) { L ('service after uninstall: ' + $s + ' ' + $svc.Status + '/' + $svc.StartType) }
}
$pc = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PC Manager' -ErrorAction SilentlyContinue
L ('PC Manager uninstall entry present after run: ' + [bool]$pc)

# ---------- 4. Ubisoft background service/task (app itself is kept) ----------
$upc = Get-Service -Name UpcElevationService -ErrorAction SilentlyContinue
if ($upc) {
    Stop-Service -Name UpcElevationService -Force -ErrorAction SilentlyContinue
    $r = & sc.exe delete UpcElevationService 2>&1
    L ('UpcElevationService deleted: ' + ($r -join ' '))
}
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -match '\\Ubisoft\\' } | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
    L ('Ubisoft task removed: ' + $_.TaskPath + $_.TaskName)
}

# ---------- 5. Defender disable (explicit user request) ----------
$wd = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
New-Item -Path $wd -Force | Out-Null
New-ItemProperty -Path $wd -Name DisableAntiSpyware -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path $wd -Name DisableAntiVirus -PropertyType DWord -Value 1 -Force | Out-Null
$rtp = Join-Path $wd 'Real-Time Protection'
New-Item -Path $rtp -Force | Out-Null
foreach ($v in @('DisableRealtimeMonitoring', 'DisableBehaviorMonitoring', 'DisableIOAVProtection',
                 'DisableOnAccessProtection', 'DisableScanOnRealtimeEnable')) {
    New-ItemProperty -Path $rtp -Name $v -PropertyType DWord -Value 1 -Force | Out-Null
}
L 'Defender policy: DisableAntiSpyware=1, DisableAntiVirus=1, real-time subkeys set'
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIOAVProtection $true -DisableScriptScanning $true -MAPSReporting 0 `
        -SubmitSamplesConsent 2 -ErrorAction Stop
    L 'Set-MpPreference applied'
} catch {
    L ('Set-MpPreference failed: ' + $_.Exception.Message)
}
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    L ('Defender now: RealTime=' + $mp.RealTimeProtectionEnabled + ' AV=' + $mp.AntivirusEnabled + ' AMService=' + $mp.AMServiceEnabled)
} catch { L 'Get-MpComputerStatus failed' }

# ---------- 6. Store games check ----------
L 'Store games: none installed (Xbox app kept by request; Capitalism Lab is a desktop app and kept)'

L '=== ELEVATED CLEANUP PHASE 2 END ==='
