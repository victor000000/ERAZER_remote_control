$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
function Remove-Folder([string]$path) {
    if (-not (Test-Path $path)) { L ('  folder gone: ' + $path); return }
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('  folder deleted: ' + $path); return } catch {
        L ('  delete denied, taking ownership: ' + $path)
    }
    & takeown.exe /f $path /r /d y | Out-Null
    & icacls.exe $path /grant "Administrators:F" /t /c /q | Out-Null
    try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop; L ('  folder deleted after ownership: ' + $path) }
    catch { L ('  folder still locked: ' + $path + ' - ' + $_.Exception.Message) }
}

L '=== DOUBAO REMOVAL START ==='
$freeBefore = (Get-PSDrive C).Free

Get-Process -Name 'Doubao' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$u = 'C:\Users\victo\AppData\Local\Doubao\Application\uninstall.exe'
if (Test-Path $u) {
    L 'running Doubao uninstaller --quiet'
    $p = Start-Process -FilePath $u -ArgumentList '--quiet' -PassThru -WindowStyle Hidden
    if ($p.WaitForExit(180000)) {
        L ('  uninstaller exit=' + $p.ExitCode)
    } else {
        L '  uninstaller still running after 180s; stopping it and cleaning manually'
        $p | Stop-Process -Force -ErrorAction SilentlyContinue
    }
} else {
    L 'uninstaller not found'
}
Start-Sleep -Seconds 8
L ('after uninstaller: uninstall key=' + [bool](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Doubao' -ErrorAction SilentlyContinue) +
   ' app folder=' + (Test-Path 'C:\Users\victo\AppData\Local\Doubao'))

# Kill anything the uninstaller restarted
Get-Process -Name 'Doubao' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Registry cleanup
try { Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Doubao' -Recurse -Force -ErrorAction SilentlyContinue; L 'removed uninstall registry key' } catch {}
try { Remove-Item 'HKCU:\Software\Doubao' -Recurse -Force -ErrorAction SilentlyContinue; L 'removed HKCU\Software\Doubao' } catch {}
try {
    Remove-Item 'HKCU:\Software\ByteDance\doubao' -Recurse -Force -ErrorAction SilentlyContinue
    $sub = @(Get-ChildItem 'HKCU:\Software\ByteDance' -ErrorAction SilentlyContinue)
    if ($sub.Count -eq 0) { Remove-Item 'HKCU:\Software\ByteDance' -Recurse -Force -ErrorAction SilentlyContinue; L 'removed empty HKCU\Software\ByteDance' }
    else { L 'HKCU\Software\ByteDance kept (other subkeys)' }
} catch {}

# Startup approval entry, if any
$approve = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
if (Get-ItemProperty $approve -Name 'Doubao' -ErrorAction SilentlyContinue) {
    Remove-ItemProperty $approve -Name 'Doubao' -ErrorAction SilentlyContinue
    L 'removed StartupApproved entry'
}

# Folders
Remove-Folder 'C:\Users\victo\AppData\Local\Doubao'
Remove-Folder 'C:\Users\victo\AppData\Roaming\Doubao'
Remove-Folder 'C:\Users\victo\Doubao'

# Shortcuts pointing at Doubao
$shell = New-Object -ComObject WScript.Shell
foreach ($d in @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
                 (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
                 (Join-Path $env:USERPROFILE 'Desktop'),
                 'C:\Users\Public\Desktop')) {
    if (Test-Path $d) {
        Get-ChildItem $d -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
            $target = ''
            try { $target = $shell.CreateShortcut($_.FullName).TargetPath } catch {}
            if ($target -match 'Doubao|doubao') {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                L ('removed shortcut: ' + $_.FullName)
            }
        }
    }
}

# App Paths entry
try {
    $ap = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Doubao.exe'
    if (Test-Path $ap) { Remove-Item $ap -Recurse -Force -ErrorAction SilentlyContinue; L 'removed App Paths entry' }
} catch {}

$freeAfter = (Get-PSDrive C).Free
L ('freed MB=' + [math]::Round(($freeAfter - $freeBefore)/1MB,1) + ' C: free GB=' + [math]::Round($freeAfter/1GB,1))
L ('processes left=' + @(Get-Process -Name 'Doubao' -ErrorAction SilentlyContinue).Count)
L ('folders left: local=' + (Test-Path 'C:\Users\victo\AppData\Local\Doubao') + ' roaming=' + (Test-Path 'C:\Users\victo\AppData\Roaming\Doubao'))
L '=== DOUBAO REMOVAL END ==='
