$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }
function Stats([string]$label, [double[]]$v) {
    if (-not $v -or $v.Count -eq 0) { W ($label + ': no samples'); return }
    $m = $v | Measure-Object -Minimum -Maximum -Average
    $avg = $m.Average
    $var = 0.0
    foreach ($x in $v) { $var += ($x - $avg) * ($x - $avg) }
    $jitter = [math]::Sqrt($var / $v.Count)
    W ($label + ': n=' + $v.Count + ' min=' + [math]::Round($m.Minimum, 1) + 'ms avg=' + [math]::Round($avg, 1) + 'ms max=' + [math]::Round($m.Maximum, 1) + 'ms jitter=' + [math]::Round($jitter, 1) + 'ms')
}
$isErazer = ($env:COMPUTERNAME -eq 'ERAZER-6JMHAKCD')
$peerLan  = if ($isErazer) { '192.168.0.2' } else { '192.168.0.5' }
$peerTs   = if ($isErazer) { '100.84.90.98' } else { '100.105.143.1' }
$ts = 'C:\Program Files\Tailscale\tailscale.exe'

W ('=== STABILITY REPORT ' + $env:COMPUTERNAME + ' ' + (Get-Date -Format 'HH:mm:ss') + ' ===')
W ('LAN peer=' + $peerLan + '  TS peer=' + $peerTs)

W '--- LINK ---'
(netsh wlan show interfaces) 2>&1 | Select-String 'SSID|Signal|Receive rate|Transmit rate|State' |
    ForEach-Object { W $_.Line.Trim() }

W '--- LAN PING (40 samples) ---'
$lan = @()
for ($i = 0; $i -lt 40; $i++) {
    $r = Test-Connection -ComputerName $peerLan -Count 1 -ErrorAction SilentlyContinue
    if ($r) { $lan += [double]$r.ResponseTime } else { $lan += -1 }
    Start-Sleep -Milliseconds 250
}
$lanOk = $lan | Where-Object { $_ -ge 0 }
$lossLan = (($lan | Where-Object { $_ -lt 0 }).Count)
Stats 'LAN' $lanOk
W ('LAN loss: ' + $lossLan + '/40')

W '--- TAILSCALE PING (20 samples) ---'
$tsOut = & $ts ping -c 20 $peerTs 2>&1
$tsTimes = @()
foreach ($line in $tsOut) {
    if ($line -match 'in ([\d.]+)ms') { $tsTimes += [double]$Matches[1] }
}
Stats 'TAILSCALE' $tsTimes
$paths = $tsOut | Where-Object { $_ -match 'via ' } | Select-Object -First 2
foreach ($p in $paths) { W ('  ' + ($p -replace '\s+', ' ').Trim()) }
if ($tsOut -match 'direct connection not established') { W '  DIRECT NOT ESTABLISHED (DERP)' } else { W '  direct path expected' }

W '--- PROXY TCP CONNECT (10 samples) ---'
$proxy = '192.168.0.2'
$pt = @()
for ($i = 0; $i -lt 10; $i++) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $c = New-Object Net.Sockets.TcpClient
        $c.Connect($proxy, 7897)
        $sw.Stop()
        $pt += $sw.Elapsed.TotalMilliseconds
        $c.Close()
    } catch { $sw.Stop() }
    Start-Sleep -Milliseconds 200
}
Stats 'PROXY TCP' $pt

W '--- DNS ---'
$dnsTimes = @()
for ($i = 0; $i -lt 5; $i++) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { Resolve-DnsName 'www.microsoft.com' -Type A -ErrorAction Stop | Out-Null } catch {}
    $sw.Stop()
    $dnsTimes += $sw.Elapsed.TotalMilliseconds
    Start-Sleep -Milliseconds 200
}
Stats 'DNS' $dnsTimes

W '--- INTERNET ICMP ---'
foreach ($ip in @('223.5.5.5', '1.1.1.1')) {
    $r = Test-Connection -ComputerName $ip -Count 4 -ErrorAction SilentlyContinue
    if ($r) {
        $a = ($r | Measure-Object -Property ResponseTime -Average).Average
        W ($ip + ': avg=' + [math]::Round($a, 1) + 'ms replies=' + $r.Count + '/4')
    } else { W ($ip + ': no ICMP reply') }
}

W '--- SERVICES / ROUTES ---'
Get-Service sshd, Tailscale, RustDesk, WinRM -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, InterfaceMetric | Format-Table -AutoSize | Out-String | Write-Output
