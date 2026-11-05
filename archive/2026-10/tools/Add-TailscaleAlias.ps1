$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$cfg = Join-Path $env:USERPROFILE '.ssh\config'
$dir = Split-Path $cfg -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$content = ''
if (Test-Path $cfg) { $content = Get-Content $cfg -Raw }
if ($content -notmatch '(?m)^Host\s+erazer-ts\s*$') {
    $block = @"

Host erazer-ts
    HostName 100.105.143.1
    User Vic
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
"@
    Add-Content -Path $cfg -Value $block -Encoding ASCII
    Write-Output 'added SSH alias erazer-ts'
} else { Write-Output 'SSH alias erazer-ts already present' }
Get-Content $cfg | Select-Object -Last 12 | ForEach-Object { Write-Output $_ }

Write-Output '=== SSH OVER TAILNET ==='
ssh -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new -o User=Vic 100.105.143.1 'echo TAILSCALE_SSH_OK' 2>&1 | ForEach-Object { Write-Output $_ }
