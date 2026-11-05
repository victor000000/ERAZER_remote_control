$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
$key = $env:TAILSCALE_AUTH_KEY

$done = $false
foreach ($tag in @('tag:erazer', 'tag:server', 'tag:windows')) {
    Write-Output ('=== TRY ' + $tag + ' ===')
    $out = & $ts up --auth-key $key --advertise-tags $tag --hostname erazer --accept-routes 2>&1
    $out | ForEach-Object { Write-Output $_ }
    if ($out -match 'Logged in|100\.') { $done = $true; break }
}

if (-not $done) {
    Write-Output '=== OAUTH TAGS FAILED; INTERACTIVE URL ==='
    $job = Start-Job -ScriptBlock {
        & 'C:\Program Files\Tailscale\tailscale.exe' up --hostname erazer --accept-routes 2>&1
    }
    Start-Sleep -Seconds 8
    Receive-Job -Job $job -Keep | ForEach-Object { Write-Output $_ }
    Write-Output ('job state: ' + (Get-Job -Id $job.Id).State)
    $url = (Receive-Job -Job $job -Keep | Out-String)
    if ($url -match 'https://login\.tailscale\.com/\S+') {
        Write-Output ('LOGIN URL: ' + $Matches[0])
    } else {
        Write-Output 'No login URL captured yet; check tailscale status.'
    }
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}

Write-Output '=== STATUS ==='
(& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
Write-Output '=== IP ==='
(& $ts ip -4 2>&1) | ForEach-Object { Write-Output $_ }
