$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\openssh-update.txt'
function W([string]$t) { Write-Output $t }

W ('OpenSSH update: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '=== BEFORE ==='
Get-Service RustDesk, sshd -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-Process rustdesk -ErrorAction SilentlyContinue |
    Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output
$oldExe = 'C:\Windows\System32\OpenSSH\sshd.exe'
if (Test-Path $oldExe) {
    W ('old sshd: ' + (Get-Item $oldExe).VersionInfo.FileVersion)
    (& $oldExe -Q kex 2>&1) | ForEach-Object { W ('OLD KEX ' + $_) }
}

$dir = 'C:\Users\Vic\ERAZER-Tools\Backups\OpenSSH'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item 'C:\ProgramData\ssh\sshd_config' (Join-Path $dir 'sshd_config.bak') -Force -ErrorAction SilentlyContinue
sc.exe qc sshd > (Join-Path $dir 'sshd-service-before.txt') 2>&1
W ('backup: ' + $dir)

$zip = Join-Path $dir 'OpenSSH-Win64-10.0.0.0p2.zip'
$url = 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64.zip'
W ('downloading: ' + $url)
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
    W ('downloaded bytes: ' + (Get-Item $zip).Length)
} catch { W ('download failed: ' + $_.Exception.Message); return }

$ext = Join-Path $dir 'extract'
if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $ext -Force
$src = Get-ChildItem $ext -Directory | Select-Object -First 1
W ('extracted: ' + $src.FullName)

W '=== INSTALL ==='
try {
    & (Join-Path $src.FullName 'Install-sshd.ps1') 2>&1 | ForEach-Object { W $_ }
} catch { W ('Install-sshd failed: ' + $_.Exception.Message) }

W '=== START / VERIFY ==='
Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
Restart-Service sshd -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Get-Service sshd -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
$newExe = Join-Path $src.FullName 'sshd.exe'
if (Test-Path $newExe) {
    W ('new sshd: ' + (Get-Item $newExe).VersionInfo.FileVersion)
    (& $newExe -Q kex 2>&1) | ForEach-Object { W ('NEW KEX ' + $_) }
}
Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue |
    Select-Object Name, PathName, State | Format-List | Out-String | Write-Output
Get-Process sshd -ErrorAction SilentlyContinue |
    Select-Object Id, Path | Format-List | Out-String | Write-Output
W 'rollback: set the sshd service binPath back to C:\Windows\System32\OpenSSH\sshd.exe (or reinstall the Windows OpenSSH.Server capability)'
