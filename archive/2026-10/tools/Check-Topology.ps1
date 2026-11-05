$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('=== ' + $env:COMPUTERNAME + ' ' + (Get-Date -Format 'HH:mm:ss') + ' ===')
W '--- IPv4 (relevant) ---'
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -match '^(192\.168\.(0|1|137)\.|10\.)' } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength |
    Format-Table -AutoSize | Out-String | Write-Output
W '--- WLAN ---'
(netsh wlan show interfaces) 2>&1 | Select-String 'SSID|Signal|State' | ForEach-Object { W $_.Line.Trim() }
W '--- DEFAULT ROUTES ---'
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric |
    Format-Table -AutoSize | Out-String | Write-Output
W '--- PROXY ---'
$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
W ('WinINET Enable=' + $p.ProxyEnable + ' Server=' + $p.ProxyServer)
W '--- TAILSCALE ---'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    Get-Service Tailscale -ErrorAction SilentlyContinue | Select-Object Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
    (& $ts status 2>&1) | Select-Object -First 5 | ForEach-Object { W $_ }
}
W '--- PROXY WATCHER TASK ---'
Get-ScheduledTask -TaskName 'SyncProxyWithNetwork' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
W '--- TARGET PINGS ---'
foreach ($ip in @('192.168.0.5','192.168.0.2','192.168.0.1','192.168.1.198','192.168.137.37')) {
    $r = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    W ($ip + ' reachable=' + $r)
}
