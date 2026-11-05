$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
function Remove-Folder([string]$path) {
    if (-not (Test-Path $path)) { L ('folder already gone: ' + $path); return $true }
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('folder deleted: ' + $path); return $true } catch {
        L ('delete denied, taking ownership: ' + $path + ' - ' + $_.Exception.Message)
    }
    & takeown.exe /f $path /r /d y | Out-Null
    & icacls.exe $path /grant "Administrators:F" /t /c /q | Out-Null
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('folder deleted after ownership: ' + $path); return $true }
    catch { L ('folder still locked: ' + $path + ' - ' + $_.Exception.Message); return $false }
}

L '=== LOCKED REMNANTS REMOVAL START ==='

# Stop and delete HONOR kernel drivers that live inside the PCManager folder
foreach ($d in @('HNOs2ECx64', 'OS2SOC', 'ProcessMonitor Service')) {
    $svc = Get-CimInstance Win32_SystemDriver -Filter ("Name='" + $d.Replace("'", "''") + "'") -ErrorAction SilentlyContinue
    if ($svc) {
        $r1 = & sc.exe stop "$d" 2>&1
        L ('stop ' + $d + ': ' + ($r1 -join ' '))
        $r2 = & sc.exe delete "$d" 2>&1
        L ('delete ' + $d + ': ' + ($r2 -join ' '))
    } else {
        L ('driver not present: ' + $d)
    }
}
Start-Sleep -Seconds 3

# Retry folder
$ok = Remove-Folder 'C:\Program Files\HONOR\PCManager'
if (-not $ok) {
    # Schedule deletion at next boot, when the deleted drivers no longer load
    $cmdPath = 'C:\ProgramData\honor-pcmanager-cleanup.cmd'
    $cmd = '@echo off' + "`r`n" + 'rmdir /s /q "C:\Program Files\HONOR\PCManager"' + "`r`n" + 'schtasks /delete /tn "HonorPCManagerCleanup" /f >nul 2>&1' + "`r`n"
    Set-Content -Path $cmdPath -Value $cmd -Encoding ASCII
    & schtasks.exe /create /tn "HonorPCManagerCleanup" /tr ("cmd /c " + $cmdPath) /sc onstart /ru SYSTEM /rl HIGHEST /f 2>&1 | ForEach-Object { L ('task: ' + $_) }
    L 'scheduled PCManager folder deletion at next boot'
}

# Ubisoft leftovers
Remove-Folder 'C:\Program Files (x86)\Ubisoft' | Out-Null

# Report driver state and folder size
foreach ($d in @('HNOs2ECx64', 'OS2SOC', 'ProcessMonitor Service')) {
    $svc = Get-CimInstance Win32_SystemDriver -Filter ("Name='" + $d.Replace("'", "''") + "'") -ErrorAction SilentlyContinue
    if ($svc) { L ('driver after: ' + $d + ' ' + $svc.State) } else { L ('driver gone: ' + $d) }
}
if (Test-Path 'C:\Program Files\HONOR\PCManager') {
    $s = (Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    L ('PCManager folder still present MB=' + [math]::Round($s/1MB,1))
} else { L 'PCManager folder gone' }
L ('Ubisoft folder present=' + (Test-Path 'C:\Program Files (x86)\Ubisoft'))
L '=== LOCKED REMNANTS REMOVAL END ==='
