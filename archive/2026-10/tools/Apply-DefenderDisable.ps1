$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== DEFENDER DISABLE ATTEMPT ==='

try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    L ('before: RTP=' + $mp.RealTimeProtectionEnabled + ' IsTamperProtected=' + $mp.IsTamperProtected + ' TamperSource=' + $mp.TamperProtectionSource)
} catch { L 'status unavailable' }

# Try to turn Tamper Protection off via registry (may be blocked)
try {
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name TamperProtection -Value 0 -Type DWord -ErrorAction Stop
    L 'TamperProtection registry set to 0'
} catch {
    L ('TamperProtection registry write failed: ' + $_.Exception.Message)
}

# Try preference-level disable (parameter exists on newer builds)
try {
    Set-MpPreference -DisableTamperProtection $true -ErrorAction Stop
    L 'Set-MpPreference -DisableTamperProtection applied'
} catch {
    L ('DisableTamperProtection not applied: ' + $_.Exception.Message)
}

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIOAVProtection $true -DisableScriptScanning $true -DisableArchiveScanning $true `
        -DisableEmailScanning $true -DisableRemovableDriveScanning $true -DisableBlockAtFirstSeen $true `
        -MAPSReporting 0 -SubmitSamplesConsent 2 -ErrorAction Stop
    L 'Set-MpPreference real-time disables applied'
} catch {
    L ('Set-MpPreference failed: ' + $_.Exception.Message)
}

# Disable Defender scheduled tasks
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\*' -ErrorAction SilentlyContinue | ForEach-Object {
    Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
    L ('defender task disabled: ' + $_.TaskName)
}

Start-Sleep -Seconds 2
try {
    $mp2 = Get-MpComputerStatus -ErrorAction Stop
    L ('after: RTP=' + $mp2.RealTimeProtectionEnabled + ' Behavior=' + $mp2.BehaviorMonitorEnabled + ' IsTamperProtected=' + $mp2.IsTamperProtected)
} catch { L 'after status unavailable' }

# Remove leftover HunterCamp service (disabled, app uninstalled)
$hc = Get-CimInstance Win32_Service -Filter "Name='HunterCampService'" -ErrorAction SilentlyContinue
if ($hc) {
    $exe = $hc.PathName
    if ($exe -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($exe -split ' ')[0] }
    L ('HunterCampService binary exists=' + (Test-Path $exe) + ' path=' + $exe)
    if (-not (Test-Path $exe)) {
        $r = & sc.exe delete HunterCampService 2>&1
        L ('deleted HunterCampService: ' + ($r -join ' '))
    }
}

# PC Manager remnants size
if (Test-Path 'C:\Program Files\HONOR\PCManager') {
    $s = (Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    L ('PCManager folder size MB=' + [math]::Round($s/1MB,1))
}
L '=== DEFENDER DISABLE ATTEMPT END ==='
