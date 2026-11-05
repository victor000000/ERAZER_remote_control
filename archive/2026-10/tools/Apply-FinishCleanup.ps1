$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== FINISH CLEANUP START ==='

Get-Process UninstallGuide -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
L 'UninstallGuide closed'

# Leftover QAX service registration (binary disabled, engine removed)
$qax = Get-CimInstance Win32_Service -Filter "Name='QAXDefender.SDK'" -ErrorAction SilentlyContinue
if ($qax) {
    & sc.exe stop QAXDefender.SDK | Out-Null
    $r = & sc.exe delete QAXDefender.SDK 2>&1
    L ('deleted QAXDefender.SDK service: ' + ($r -join ' '))
}

# Protected Xbox system app: try all-users removal
try {
    $pkg = Get-AppxPackage -AllUsers -Name 'Microsoft.XboxGameCallableUI' -ErrorAction Stop
    if ($pkg) {
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        L 'Microsoft.XboxGameCallableUI removed (all users)'
    }
} catch {
    L ('Microsoft.XboxGameCallableUI all-users removal failed (Windows system app): ' + $_.Exception.Message)
}

L '--- appx check ---'
foreach ($n in @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp', 'Microsoft.WindowsFeedbackHub',
                 'Clipchamp.Clipchamp', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.YourPhone', 'A-Volute.Nahimic',
                 'Microsoft.GamingApp', 'Microsoft.GamingServices', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxGamingOverlay',
                 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.XboxGameCallableUI',
                 'Microsoft.Todos', 'Microsoft.Windows.Photos', 'Microsoft.WindowsCamera', 'Microsoft.MicrosoftStickyNotes',
                 'Microsoft.ZuneMusic')) {
    $p = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
    L ('  ' + $n + ' present=' + [bool]$p)
}

L '--- services ---'
foreach ($s in @('MBAMainService', 'HnPCAIService', 'HnPCInferEngine', 'HnUpdateService', 'HunterCampService',
                 'QAXDefender.SDK', 'QaxEngManager', 'NahimicService', 'XblAuthManager', 'XblGameSave',
                 'XboxGipSvc', 'XboxNetApiSvc', 'GameInputRedistService', 'UpcElevationService')) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) { L ('  ' + $s + ' ' + $svc.Status + '/' + $svc.StartType) } else { L ('  ' + $s + ' gone') }
}

L '--- defender ---'
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    L ('  RealTime=' + $mp.RealTimeProtectionEnabled + ' AV=' + $mp.AntivirusEnabled + ' AMService=' + $mp.AMServiceEnabled)
} catch { L '  status unavailable' }
$dp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -ErrorAction SilentlyContinue
L ('  policy DisableAntiSpyware=' + $dp.DisableAntiSpyware + ' DisableAntiVirus=' + $dp.DisableAntiVirus)

L '--- honor remnants ---'
L ('  PCManager folder=' + (Test-Path 'C:\Program Files\HONOR\PCManager'))
L ('  PCManager uninstall entry=' + [bool](Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PC Manager' -ErrorAction SilentlyContinue))
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'PCManager|Honor|HnPCAI|HunterCamp|Qax|qax' } |
    ForEach-Object { L ('  process: ' + $_.Name + ' pid=' + $_.Id) }
L '=== FINISH CLEANUP END ==='
