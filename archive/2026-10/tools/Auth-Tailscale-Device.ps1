$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
Get-Process tailscale -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$key = $env:TAILSCALE_AUTH_KEY
Write-Output '=== TAILSCALE UP (device auth key) ==='
(& $ts up --auth-key $key --hostname erazer --accept-routes 2>&1) | ForEach-Object { Write-Output $_ }
Start-Sleep -Seconds 5
Write-Output '=== STATUS ==='
(& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
Write-Output '=== IP ==='
(& $ts ip -4 2>&1) | ForEach-Object { Write-Output $_ }
