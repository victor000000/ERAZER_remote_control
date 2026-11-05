$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$dir = 'C:\Users\victo\ERAZER_remote_control\out'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$exe = Join-Path $dir 'tailscale-setup-latest.exe'
if (-not (Test-Path $exe)) {
    Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 300
}
Write-Output ('installer bytes: ' + (Get-Item $exe).Length)
if (-not (Test-Path 'C:\Program Files\Tailscale\tailscale.exe')) {
    $p = Start-Process -FilePath $exe -ArgumentList '/quiet' -Verb RunAs -Wait -PassThru -ErrorAction SilentlyContinue
    Write-Output ('installer exit: ' + $p.ExitCode)
    Start-Sleep -Seconds 8
} else { Write-Output 'Tailscale already installed' }
Get-Service Tailscale -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    (& $ts version 2>&1) | ForEach-Object { Write-Output $_ }
    $key = $env:TAILSCALE_AUTH_KEY
    (& $ts up --auth-key $key --hostname stupicvicpc --accept-routes 2>&1) | ForEach-Object { Write-Output $_ }
    Start-Sleep -Seconds 5
    (& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
    (& $ts ip -4 2>&1) | ForEach-Object { Write-Output $_ }
} else { Write-Output 'tailscale.exe missing' }
