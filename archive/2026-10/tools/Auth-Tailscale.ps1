$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
$dir = 'C:\Users\Vic\ERAZER-Tools\Backups\Tailscale'
$exe = Join-Path $dir 'tailscale-setup-latest.exe'

if (-not (Test-Path $ts)) {
    if (-not (Test-Path $exe)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 300
    }
    Start-Process -FilePath $exe -ArgumentList '/quiet' -Wait
    Start-Sleep -Seconds 8
}
if (-not (Test-Path $ts)) { Write-Output 'INSTALL_FAILED'; return }
Start-Service Tailscale -ErrorAction SilentlyContinue
Get-Service Tailscale | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
(& $ts version 2>&1) | ForEach-Object { Write-Output $_ }

$authKey = $env:TAILSCALE_AUTH_KEY
Write-Output '=== TAILSCALE UP ==='
(& $ts up --auth-key $authKey --hostname erazer --accept-routes 2>&1) | ForEach-Object { Write-Output $_ }
Start-Sleep -Seconds 5
Write-Output '=== STATUS ==='
(& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
Write-Output '=== IP ==='
(& $ts ip -4 2>&1) | ForEach-Object { Write-Output $_ }
