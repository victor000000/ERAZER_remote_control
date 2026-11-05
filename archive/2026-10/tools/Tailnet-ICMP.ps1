$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$isErazer = ($env:COMPUTERNAME -eq 'ERAZER-6JMHAKCD')
$peer = if ($isErazer) { '100.84.90.98' } else { '100.105.143.1' }
$t = @()
for ($i = 0; $i -lt 20; $i++) {
    $r = Test-Connection -ComputerName $peer -Count 1 -ErrorAction SilentlyContinue
    if ($r) { $t += [double]$r.ResponseTime } else { $t += -1 }
    Start-Sleep -Milliseconds 200
}
$ok = $t | Where-Object { $_ -ge 0 }
if ($ok.Count -gt 0) {
    $m = $ok | Measure-Object -Minimum -Maximum -Average
    $v = 0.0
    foreach ($x in $ok) { $v += ($x - $m.Average) * ($x - $m.Average) }
    Write-Output ('TAILNET ICMP: n=' + $ok.Count + ' min=' + [math]::Round($m.Minimum, 1) + 'ms avg=' + [math]::Round($m.Average, 1) + 'ms max=' + [math]::Round($m.Maximum, 1) + 'ms jitter=' + [math]::Round([math]::Sqrt($v / $ok.Count), 1) + 'ms loss=' + (($t | Where-Object { $_ -lt 0 }).Count) + '/20')
} else { Write-Output 'TAILNET ICMP: no replies' }
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    (& $ts ping -c 1 $peer 2>&1) | Select-Object -First 2 | ForEach-Object { Write-Output $_ }
}
