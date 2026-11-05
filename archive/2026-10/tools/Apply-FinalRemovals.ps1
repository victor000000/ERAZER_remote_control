$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
function Remove-Folder([string]$path) {
    if (-not (Test-Path $path)) { L ('folder already gone: ' + $path); return }
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('folder deleted: ' + $path); return } catch {
        L ('delete denied, taking ownership: ' + $path + ' - ' + $_.Exception.Message)
    }
    & takeown.exe /f $path /r /d y | Out-Null
    & icacls.exe $path /grant "Administrators:F" /t /c /q | Out-Null
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('folder deleted after ownership: ' + $path) }
    catch { L ('folder still cannot be deleted: ' + $path + ' - ' + $_.Exception.Message) }
}

L '=== FINAL REMOVALS START ==='
$freeBefore = (Get-PSDrive C).Free

# A) HONOR PCManager folder
$pm = 'C:\Program Files\HONOR\PCManager'
$refs = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like ('*' + $pm + '*') }
if ($refs) {
    $refs | ForEach-Object { L ('service still references PCManager: ' + $_.Name + ' ' + $_.PathName) }
} else {
    L 'no service references PCManager folder'
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like ($pm + '*') } | ForEach-Object {
        L ('stopping process locking folder: ' + $_.Name + ' pid=' + $_.Id)
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Folder $pm
}

# B) GuardService (HONOR)
$gs = Get-Service GuardService -ErrorAction SilentlyContinue
if ($gs) {
    Stop-Service GuardService -Force -ErrorAction SilentlyContinue
    Set-Service GuardService -StartupType Disabled -ErrorAction SilentlyContinue
    $r = & sc.exe delete GuardService 2>&1
    L ('GuardService delete: ' + ($r -join ' '))
} else { L 'GuardService not present' }
Start-Sleep -Seconds 2
if (-not (Get-Service GuardService -ErrorAction SilentlyContinue)) {
    Remove-Folder 'C:\Program Files\HONOR\GuardService'
}

# C) Ubisoft Connect launcher
$ubiExe = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\Uninstall.exe'
if (Test-Path $ubiExe) {
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'UbisoftConnect|Uplay|Upc' } | Stop-Process -Force -ErrorAction SilentlyContinue
    L 'running Ubisoft Connect uninstaller /S'
    $p = Start-Process -FilePath $ubiExe -ArgumentList '/S' -PassThru -WindowStyle Hidden
    if ($p.WaitForExit(240000)) { L ('  Ubisoft uninstall exit=' + $p.ExitCode) } else { L '  WARNING Ubisoft uninstaller still running after 240s' }
    Start-Sleep -Seconds 3
    L ('  Ubisoft uninstall entry present=' + [bool](Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Uplay' -ErrorAction SilentlyContinue))
    L ('  Ubisoft folder present=' + (Test-Path 'C:\Program Files (x86)\Ubisoft'))
} else { L 'Ubisoft uninstaller not found' }

# D) Sticky Notes app
$sn = Get-AppxPackage -Name 'Microsoft.MicrosoftStickyNotes' -ErrorAction SilentlyContinue
if ($sn) {
    try { Remove-AppxPackage -Package $sn.PackageFullName -ErrorAction Stop; L 'appx removed: Microsoft.MicrosoftStickyNotes' }
    catch { L ('Sticky Notes remove failed: ' + $_.Exception.Message) }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'Microsoft.MicrosoftStickyNotes' }
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        L 'provisioned removed: Microsoft.MicrosoftStickyNotes'
    }
} else { L 'Sticky Notes not present' }

# E) Xbox Windows capabilities (removes the protected system component legitimately)
$caps = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Xbox\.' }
if ($caps) {
    foreach ($c in $caps) {
        L ('capability found: ' + $c.Name + ' state=' + $c.State)
        if ($c.State -ne 'NotPresent') {
            try {
                Remove-WindowsCapability -Online -Name $c.Name -ErrorAction Stop | Out-Null
                $after = Get-WindowsCapability -Online -Name $c.Name -ErrorAction SilentlyContinue
                L ('  removed, now state=' + $after.State)
            } catch {
                L ('  remove failed: ' + $_.Exception.Message)
            }
        }
    }
} else { L 'no Xbox.* capabilities found' }

# F) Disable Game Bar / Game DVR / Game Mode functions
$gdvr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
New-Item -Path $gdvr -Force | Out-Null
New-ItemProperty -Path $gdvr -Name AllowGameDVR -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
$gameDvr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
New-Item -Path $gameDvr -Force | Out-Null
New-ItemProperty -Path $gameDvr -Name AppCaptureEnabled -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
$gameBar = 'HKCU:\Software\Microsoft\GameBar'
New-Item -Path $gameBar -Force | Out-Null
New-ItemProperty -Path $gameBar -Name AutoGameModeEnabled -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $gameBar -Name AllowAutoGameMode -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $gameBar -Name UseNexusForGameBarEnabled -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
L 'Game Bar / GameDVR / Game Mode policies disabled'

$freeAfter = (Get-PSDrive C).Free
L ('freed this pass MB=' + [math]::Round(($freeAfter - $freeBefore)/1MB,1))
L '=== FINAL REMOVALS END ==='
