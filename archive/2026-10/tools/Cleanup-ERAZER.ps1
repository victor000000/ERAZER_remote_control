#requires -RunAsAdministrator
# ERAZER simplification pass: remove OEM/browser bloat, trim startup and
# unnecessary services, set a performance power profile, and prevent
# surprise update reboots while a user is logged on.
# MT5, SQX, RustDesk, MWB, SSH, Bluetooth and Defender are left untouched.

$log = 'C:\Windows\Temp\cleanup-erazer.log'
function Log([string]$m) {
    $line = "$(Get-Date -Format o) $m"
    $line | Add-Content -Path $log -Encoding UTF8
    Write-Host $line
}
"=== cleanup run ===" | Out-File $log -Encoding utf8

# --- 1. Uninstall known bloat ------------------------------------------------
$uninstallers = @(
    @{ Name = 'Lenovo SLBrowser'; Path = 'C:\Program Files (x86)\Lenovo\SLBrowser\BsUninstall.exe'; Args = '/S' },
    @{ Name = 'Blasoul PCAppStore'; Path = 'C:\Program Files (x86)\Blasoul\PCAppStore\StoreUninstaller.exe'; Args = '/SILENT' },
    @{ Name = 'Blasoul PCManager'; Path = 'C:\Program Files (x86)\Blasoul\PCManager\5.1.120.9242\uninst.exe'; Args = '/S' },
    @{ Name = 'Logi Download Assistant'; Path = 'C:\Program Files\LogiDownloadAssistant\Uninstall.exe'; Args = '/S' }
)
foreach ($u in $uninstallers) {
    if (Test-Path -LiteralPath $u.Path) {
        Log "uninstall launch: $($u.Name)"
        try {
            Start-Process -FilePath $u.Path -ArgumentList $u.Args -ErrorAction Stop
            Log '  launched'
        }
        catch { Log "  error: $($_.Exception.Message)" }
    }
    else { Log "uninstaller missing: $($u.Name)" }
}

# OneDrive (per-user install)
$oneDrive = 'C:\Users\Vic\AppData\Local\Microsoft\OneDrive\23.081.0416.0001\OneDriveSetup.exe'
if (Test-Path -LiteralPath $oneDrive) {
    Log 'uninstall launch: Microsoft OneDrive'
    try { Start-Process -FilePath $oneDrive -ArgumentList '/uninstall' -ErrorAction Stop }
    catch { Log "  error: $($_.Exception.Message)" }
}

# Clipchamp (Store app)
try {
    Get-AppxPackage -Name Clipchamp.Clipchamp -ErrorAction SilentlyContinue |
        Remove-AppxPackage -ErrorAction SilentlyContinue
    Log 'removed Clipchamp appx (if present)'
}
catch { Log "clipchamp error: $($_.Exception.Message)" }

Start-Sleep -Seconds 20

# --- 2. Startup entries ------------------------------------------------------
$runKeys = @(
    @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Names = @('OneDriveSetup', 'OneDrive') },
    @{ Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Names = @('Logi Download Assistant', 'Logitech Download Assistant') }
)
foreach ($rk in $runKeys) {
    foreach ($n in $rk.Names) {
        try {
            if (Get-ItemProperty -Path $rk.Key -Name $n -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $rk.Key -Name $n -ErrorAction Stop
                Log "startup removed: $n"
            }
        }
        catch { Log "startup remove error ($n): $($_.Exception.Message)" }
    }
}

# --- 3. Services -------------------------------------------------------------
$disable = 'DiagTrack', 'MapsBroker', 'PhoneSvc', 'RetailDemo', 'Spooler', 'SysMain',
    'WalletService', 'WMPNetworkSvc', 'WSearch', 'XblAuthManager', 'XblGameSave',
    'XboxGipSvc', 'XboxNetApiSvc', 'WerSvc',
    'BlasoulPcManagerService', 'BsService', 'HRWSCCtrl', 'PCAppStoreServiceAS',
    'LISFService', 'LnvSvcFdn'
foreach ($svc in $disable) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        try {
            Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Log "service disabled: $svc"
        }
        catch { Log "service error ($svc): $($_.Exception.Message)" }
    }
}

# --- 4. Power / stability ----------------------------------------------------
try {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    powercfg /change standby-timeout-ac 0 | Out-Null
    powercfg /change hibernate-timeout-ac 0 | Out-Null
    powercfg /change monitor-timeout-ac 15 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    Log 'power: high performance, no AC sleep/hibernate, lid-close does nothing on AC'
}
catch { Log "powercfg error: $($_.Exception.Message)" }

try {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    if (-not (Test-Path $wu)) { New-Item -Path $wu -Force | Out-Null }
    Set-ItemProperty -Path $wu -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord
    Log 'windows update: automatic reboot with logged-on users disabled'
}
catch { Log "update policy error: $($_.Exception.Message)" }

# --- 5. Temp cleanup ---------------------------------------------------------
try {
    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Log 'temp files cleared'
}
catch { Log "temp cleanup error: $($_.Exception.Message)" }

Log '=== cleanup finished ==='
