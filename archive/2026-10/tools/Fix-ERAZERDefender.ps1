$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\defender-fix.txt'
function W([string]$t) { Write-Output $t }

W ('Defender fix: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$rt = $pol + '\Real-Time Protection'

W '=== POLICY BEFORE ==='
if (Test-Path $pol) {
    Get-ChildItem $pol -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        W ('KEY ' + $_.Name)
        Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue | Out-String | ForEach-Object { W $_.Trim() }
    }
} else { W 'no Windows Defender policy key' }

$feat = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -ErrorAction SilentlyContinue
W ('TamperProtection=' + $feat.TamperProtection + ' TamperProtectionSource=' + $feat.TamperProtectionSource)

W '=== REMOVE POLICY ==='
Remove-Item $rt -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $pol -Recurse -Force -ErrorAction SilentlyContinue
gpupdate /force 2>&1 | ForEach-Object { W $_ }

W '=== ENABLE REAL-TIME ==='
try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop; W 'DisableRealtimeMonitoring=false ok' }
catch { W ('Set-MpPreference failed: ' + $_.Exception.Message) }
try { Set-MpPreference -DisableIOAVProtection $false -ErrorAction Stop }
catch { W ('IOAV failed: ' + $_.Exception.Message) }
try { Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction Stop }
catch { W ('Behavior failed: ' + $_.Exception.Message) }
try { Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction Stop }
catch { W ('BlockAtFirstSeen failed: ' + $_.Exception.Message) }

W '=== STATUS AFTER ==='
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, BehaviorMonitorEnabled,
        IoavProtectionEnabled, AntispywareEnabled, IsTamperProtected |
    Format-List | Out-String | Write-Output
Get-MpPreference -ErrorAction SilentlyContinue |
    Select-Object DisableRealtimeMonitoring, DisableIOAVProtection, DisableBehaviorMonitoring, DisableBlockAtFirstSeen |
    Format-List | Out-String | Write-Output
$feat2 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -ErrorAction SilentlyContinue
W ('TamperProtection now=' + $feat2.TamperProtection + ' Source=' + $feat2.TamperProtectionSource)
