$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$cfg = Join-Path $env:USERPROFILE '.ssh\config'
$content = Get-Content $cfg -Raw
$block = @"
Host erazer-ts
    HostName 100.105.143.1
    User Vic
    IdentityFile C:/Users/victo/.ssh/erazer_ed25519
    UserKnownHostsFile C:/Users/victo/.ssh/erazer_known_hosts
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
"@
$content = [regex]::Replace($content, '(?ms)^Host erazer-ts\r?\n(?:[ \t]+.*\r?\n)*', ($block.TrimEnd() + "`r`n"))
Set-Content -Path $cfg -Value $content -Encoding ASCII
Write-Output '=== SSH CONFIG (tail) ==='
Get-Content $cfg | Select-Object -Last 22 | ForEach-Object { Write-Output $_ }

Write-Output '=== SSH OVER TAILNET ==='
ssh -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new -o User=Vic -i C:/Users/victo/.ssh/erazer_ed25519 100.105.143.1 'echo TAILSCALE_SSH_OK' 2>&1 | ForEach-Object { Write-Output $_ }
