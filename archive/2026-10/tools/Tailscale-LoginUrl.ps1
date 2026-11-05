$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'

Get-Process tailscale -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$job = Start-Job -ScriptBlock {
    & 'C:\Program Files\Tailscale\tailscale.exe' up --hostname erazer --accept-routes 2>&1
}
Start-Sleep -Seconds 10
$out = (Receive-Job -Job $job -Keep | Out-String)
Write-Output $out
$url = [regex]::Match($out, 'https://login\.tailscale\.com/\S+').Value
if ($url) { Write-Output ('LOGIN_URL=' + $url) } else { Write-Output 'NO_LOGIN_URL_CAPTURED' }
Write-Output ('job state: ' + (Get-Job -Id $job.Id).State)
