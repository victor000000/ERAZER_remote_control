$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== XBOX REMOVAL START ==='

$xbox = @(
    'Microsoft.GamingApp',
    'Microsoft.GamingServices',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxGameCallableUI',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay'
)
foreach ($n in $xbox) {
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
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            L ('provisioned removed: ' + $n)
        } catch {
            L ('provisioned remove failed: ' + $n + ' - ' + $_.Exception.Message)
        }
    }
}

foreach ($s in @('XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc', 'GameInputRedistService', 'GameInputSvc')) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        $now = Get-Service -Name $s -ErrorAction SilentlyContinue
        L ('service ' + $s + ' -> ' + $now.Status + '/' + $now.StartType)
    } else {
        L ('service not present: ' + $s)
    }
}

# Orphan HONOR update service (binary was already removed by the component uninstaller)
$h = Get-CimInstance Win32_Service -Filter "Name='HnUpdateService'" -ErrorAction SilentlyContinue
if ($h) {
    $svcPath = $h.PathName
    if ($svcPath -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($svcPath -split ' ')[0] }
    if (-not (Test-Path $exe)) {
        $r = & sc.exe delete HnUpdateService 2>&1
        L ('deleted orphan service HnUpdateService: ' + ($r -join ' '))
    } else {
        L 'HnUpdateService binary still present, left disabled'
    }
}

L '--- remaining xbox appx ---'
$left = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Xbox|GamingApp|GamingServices' }
if ($left) { $left | ForEach-Object { L ('  left: ' + $_.Name + ' ' + $_.Version) } } else { L '  none' }
L '=== XBOX REMOVAL END ==='
