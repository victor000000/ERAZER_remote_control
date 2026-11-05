$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'

Write-Output '=== TAILSCALE SET (protect local network) ==='
(& $ts set --accept-dns=false --accept-routes=false 2>&1) | ForEach-Object { Write-Output $_ }
(& $ts set --exit-node= 2>&1) | ForEach-Object { Write-Output $_ }
Start-Sleep -Seconds 2

Write-Output '=== TLS STATUS ==='
(& $ts status 2>&1) | ForEach-Object { Write-Output $_ }

Write-Output '=== DEFAULT ROUTES ==='
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric |
    Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== DNS ==='
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.ServerAddresses } |
    Select-Object InterfaceAlias, ServerAddresses |
    Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== ADAPTERS / HOTSPOT / WLAN ==='
Get-NetAdapter -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed |
    Format-Table -AutoSize | Out-String | Write-Output
(netsh wlan show interfaces) | Select-String 'SSID|Signal|Receive rate|Transmit rate|State' |
    ForEach-Object { Write-Output $_.Line.Trim() }
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '192.168.137.*' } |
    Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== PROXY ==='
$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
Write-Output ('WinINET Enable=' + $p.ProxyEnable + ' Server=' + $p.ProxyServer + ' Override=' + $p.ProxyOverride)
(netsh winhttp show proxy) | ForEach-Object { Write-Output $_ }
