$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- FOLDERS ---'
foreach ($d in @('C:\Program Files\HONOR\PCManager', 'C:\Program Files\HONOR\GuardService', 'C:\Program Files (x86)\Ubisoft')) {
    W ('  ' + $d + ' exists=' + (Test-Path $d))
}

W '--- HONOR SERVICES/DRIVERS LEFT ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|Honor|HunterCamp|qianxin' } |
    Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Output
Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|Honor|OS2SOC|ProcessMonitor' } |
    Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Output

W '--- SERVICES WITH MISSING BINARIES ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
    $exe = $_.PathName
    if ($exe) {
        if ($exe -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($exe -split ' ')[0] }
        if ($exe -match '^[A-Za-z]:\\' -and -not (Test-Path $exe)) {
            W ('  MISSING: ' + $_.Name + ' -> ' + $exe)
        }
    }
}

W '--- UBISOFT ---'
W ('  uninstall entry=' + [bool](Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Uplay' -ErrorAction SilentlyContinue))
W ('  processes=' + @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Ubisoft|Uplay|Upc' }).Count)

W '--- STICKY NOTES ---'
W ('  appx=' + [bool](Get-AppxPackage -Name 'Microsoft.MicrosoftStickyNotes' -ErrorAction SilentlyContinue))

W '--- XBOX ---'
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Xbox|GamingApp|GamingServices' } |
    Select-Object Name, Version | Format-Table -AutoSize | Out-String | Write-Output
W ('  AllowGameDVR=' + (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -ErrorAction SilentlyContinue).AllowGameDVR)
W ('  GameDVR_Enabled=' + (Get-ItemProperty 'HKCU:\System\GameConfigStore' -ErrorAction SilentlyContinue).GameDVR_Enabled)
W ('  AutoGameModeEnabled=' + (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled)
$xb = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Xbl|^Xbox|GameInput' }
foreach ($s in $xb) { W ('  svc ' + $s.Name + ' ' + $s.State + '/' + $s.StartMode) }

W '--- DEFENDER ---'
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    W ('  RTP=' + $mp.RealTimeProtectionEnabled + ' Behavior=' + $mp.BehaviorMonitorEnabled + ' Tamper=' + $mp.IsTamperProtected)
} catch { W '  status failed' }

W '--- HONOR PROCESSES ---'
$hp = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'PCManager|HnPCAI|HNPCInfer|HunterCamp|Qax|qax|HnPerf|HnUpdate' }
if ($hp) { $hp | Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output } else { W '  none' }

W '--- DISK / RAM ---'
Get-PSDrive C | ForEach-Object { W ('  C: free GB=' + [math]::Round($_.Free/1GB,1)) }
$os = Get-CimInstance Win32_OperatingSystem
W ('  RAM free MB=' + [math]::Round($os.FreePhysicalMemory/1KB))
