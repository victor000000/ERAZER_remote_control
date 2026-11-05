$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$proxy = 'http://192.168.137.1:7897'
$url = 'https://controlplane.tailscale.com/derpmap/default'

Write-Output '=== DIRECT ==='
try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
    Write-Output ('status=' + $r.StatusCode + ' bytes=' + $r.RawContentLength)
} catch { Write-Output ('direct failed: ' + $_.Exception.Message) }

Write-Output '=== PROXY ==='
try {
    $r = Invoke-WebRequest -Uri $url -Proxy $proxy -UseBasicParsing -TimeoutSec 20
    Write-Output ('status=' + $r.StatusCode + ' bytes=' + $r.RawContentLength)
} catch { Write-Output ('proxy failed: ' + $_.Exception.Message) }

Write-Output '=== SET MACHINE PROXY ENV + SERVICE ENV ==='
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, 'Machine')
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, 'Machine')
$svc = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tailscale'
Set-ItemProperty -Path $svc -Name Environment -Value @("HTTPS_PROXY=$proxy", "HTTP_PROXY=$proxy") -Type MultiString -ErrorAction SilentlyContinue
Write-Output 'machine env and service Environment set'

Restart-Service Tailscale -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Get-Service Tailscale | Select-Object Name, Status | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== TAILSCALE UP ==='
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
$key = $env:TAILSCALE_AUTH_KEY
(& $ts up --auth-key $key --hostname erazer --accept-routes 2>&1) | ForEach-Object { Write-Output $_ }
Start-Sleep -Seconds 5
Write-Output '=== STATUS ==='
(& $ts status 2>&1) | ForEach-Object { Write-Output $_ }
Write-Output '=== IP ==='
(& $ts ip -4 2>&1) | ForEach-Object { Write-Output $_ }
