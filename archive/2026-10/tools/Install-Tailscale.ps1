$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
Write-Output ('arch=' + $env:PROCESSOR_ARCHITECTURE)

Write-Output '=== CONNECTIVITY ==='
Test-NetConnection login.tailscale.com -Port 443 -InformationLevel Detailed -ErrorAction SilentlyContinue |
    Select-Object ComputerName, RemoteAddress, TcpTestSucceeded | Format-List | Out-String | Write-Output
Test-NetConnection controlplane.tailscale.com -Port 443 -InformationLevel Detailed -ErrorAction SilentlyContinue |
    Select-Object ComputerName, RemoteAddress, TcpTestSucceeded | Format-List | Out-String | Write-Output

$dir = 'C:\Users\Vic\ERAZER-Tools\Backups\Tailscale'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$exe = Join-Path $dir 'tailscale-setup-latest.exe'
if (-not (Test-Path $exe)) {
    Write-Output '=== DOWNLOAD ==='
    try {
        Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
        Write-Output ('downloaded bytes: ' + (Get-Item $exe).Length)
    } catch { Write-Output ('download failed: ' + $_.Exception.Message); return }
}

Write-Output '=== INSTALL (quiet) ==='
if (-not (Test-Path 'C:\Program Files\Tailscale\tailscale.exe')) {
    Start-Process -FilePath $exe -ArgumentList '/quiet' -Wait -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
} else { Write-Output 'already installed' }

$ts = 'C:\Program Files\Tailscale\tailscale.exe'
Get-Service Tailscale -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
if (Test-Path $ts) {
    (& $ts version 2>&1) | ForEach-Object { Write-Output $_ }
    Write-Output '=== STATUS ==='
    (& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
    Write-Output '=== LOGIN URL (open it and approve this device) ==='
    (& $ts up --hostname erazer 2>&1) | ForEach-Object { Write-Output $_ }
} else { Write-Output 'tailscale.exe missing after install' }
