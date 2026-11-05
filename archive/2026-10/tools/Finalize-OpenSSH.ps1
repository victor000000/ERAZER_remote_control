$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$src = 'C:\Users\Vic\ERAZER-Tools\Backups\OpenSSH\extract\OpenSSH-Win64'
$dst = 'C:\Program Files\OpenSSH'

Write-Output '=== MOVE TO PERMANENT PATH ==='
if (Test-Path $src) {
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    Copy-Item (Join-Path $src '*') $dst -Recurse -Force
    Write-Output ('copied to ' + $dst)
} else { Write-Output ('source missing: ' + $src) }

Write-Output '=== SERVICE PATH ==='
sc.exe config sshd binPath= '"C:\Program Files\OpenSSH\sshd.exe"' 2>&1 | ForEach-Object { Write-Output $_ }
Restart-Service sshd -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue |
    Select-Object Name, PathName, State, StartMode | Format-List | Out-String | Write-Output
if (Test-Path (Join-Path $dst 'sshd.exe')) {
    (& (Join-Path $dst 'sshd.exe') -V 2>&1) | ForEach-Object { Write-Output $_ }
}
Get-Process sshd -ErrorAction SilentlyContinue |
    Select-Object Id, Path | Format-List | Out-String | Write-Output
