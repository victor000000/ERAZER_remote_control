$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('=== NETWORK SNAPSHOT ' + $env:COMPUTERNAME + ' ' + (Get-Date -Format 'HH:mm:ss') + ' ===')
W '--- ADAPTERS UP ---'
Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' |
    Select-Object Name, InterfaceDescription, LinkSpeed |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- IPv4 ADDRESSES / GATEWAYS ---'
Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Where-Object { $_.IPv4Address } |
    Select-Object InterfaceAlias,
        @{n='IPv4';e={($_.IPv4Address.IPAddress -join ',')}},
        @{n='GW';e={($_.IPv4DefaultGateway.NextHop -join ',')}},
        @{n='Metric';e={($_.NetIPInterface.InterfaceMetric -join ',')}} |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- DEFAULT ROUTES ---'
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- DNS SERVERS ---'
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.ServerAddresses } |
    Select-Object InterfaceAlias, ServerAddresses |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- WLAN ---'
(netsh wlan show interfaces) 2>&1 | Select-String 'SSID|BSSID|Signal|Receive rate|Transmit rate|State|Radio type' |
    ForEach-Object { W $_.Line.Trim() }

W '--- PROXY ---'
$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
W ('WinINET Enable=' + $p.ProxyEnable + ' Server=' + $p.ProxyServer + ' Override=' + $p.ProxyOverride)
(netsh winhttp show proxy 2>&1) | ForEach-Object { W $_ }

W '--- TAILSCALE ---'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    (& $ts status 2>&1) | ForEach-Object { W $_ }
    (& $ts ip -4 2>&1) | ForEach-Object { W $_ }
}

W '--- LATENCY ---'
if ($env:COMPUTERNAME -eq 'ERAZER-6JMHAKCD') {
    $peerLan = '192.168.137.1'
    $peerTs = '100.84.90.98'
} else {
    $peerLan = '192.168.137.37'
    $peerTs = '100.105.143.1'
}
foreach ($t in @(@('LAN', $peerLan), @('TAILNET', $peerTs))) {
    $r = Test-Connection -ComputerName $t[1] -Count 4 -ErrorAction SilentlyContinue
    if ($r) {
        $avg = ($r | Measure-Object -Property ResponseTime -Average).Average
        $loss = 4 - $r.Count
        W ($t[0] + ' ' + $t[1] + ': avg=' + [math]::Round($avg, 1) + 'ms loss=' + $loss + '/4')
    } else { W ($t[0] + ' ' + $t[1] + ': no response') }
}
if (Test-Path $ts) {
    W '--- TAILSCALE PING ---'
    (& $ts ping -c 3 $peerTs 2>&1) | ForEach-Object { W $_ }
}
