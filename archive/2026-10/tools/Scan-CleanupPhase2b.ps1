$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- HONOR / QAX SERVICES ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'HnPC|HunterCamp|MBAMain|QAX|Qax|GuardService|HONOR' -or $_.PathName -match 'HONOR|Honor|qianxin' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Format-List | Out-String -Width 240 | Write-Output

W '--- HONOR TASKS ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'HONOR|Honor|Hunter|Nahimic' -or $_.TaskPath -match 'HONOR|Honor' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- HONOR PC MANAGER UNINSTALL ENTRIES ---'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'HONOR|荣耀|PCManager|电脑管家|Control Center|控制中心' } |
    ForEach-Object {
        W ('KEY=' + $_.PSChildName)
        W ('  DisplayName=' + $_.DisplayName)
        W ('  DisplayVersion=' + $_.DisplayVersion)
        W ('  InstallLocation=' + $_.InstallLocation)
        W ('  UninstallString=' + $_.UninstallString)
        W ('  QuietUninstallString=' + $_.QuietUninstallString)
    }

W '--- HONOR FOLDERS ---'
foreach ($d in @('C:\Program Files\HONOR', 'C:\Program Files (x86)\HONOR', 'C:\ProgramData\HONOR')) {
    if (Test-Path $d) {
        W ('DIR ' + $d)
        Get-ChildItem $d -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { W ('  ' + $_) }
    }
}

W '--- DEFENDER STATE ---'
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    W ('RealTimeProtectionEnabled=' + $mp.RealTimeProtectionEnabled + ' AntivirusEnabled=' + $mp.AntivirusEnabled + ' AMServiceEnabled=' + $mp.AMServiceEnabled)
    W ('TamperProtectionSource=' + $mp.TamperProtectionSource + ' BehaviorMonitorEnabled=' + $mp.BehaviorMonitorEnabled)
} catch { W ('Get-MpComputerStatus failed: ' + $_.Exception.Message) }
$dp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -ErrorAction SilentlyContinue
W ('Policy DisableAntiSpyware=' + $dp.DisableAntiSpyware + ' DisableAntiVirus=' + $dp.DisableAntiVirus)
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -ErrorAction SilentlyContinue |
    ForEach-Object { W ('TamperProtection reg=' + $_.TamperProtection) }

W '--- NAHIMIC APPX ---'
Get-AppxPackage -Name 'A-Volute.Nahimic' -ErrorAction SilentlyContinue |
    Select-Object Name, Version, PackageFullName, InstallLocation | Format-List | Out-String | Write-Output

W '--- UBI SOFT FOLDER ---'
if (Test-Path 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\Uninstall.exe') { W 'uninstaller present' } else { W 'uninstaller missing' }
(Get-Process -Name '*ubisoft*','*upc*' -ErrorAction SilentlyContinue | Select-Object Name, Id | Format-Table -AutoSize | Out-String) | Write-Output
