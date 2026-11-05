$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== STOP CURRENT ==='
try { Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=stop%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30 | Out-Null } catch {}
Start-Sleep -Seconds 4
Get-Process sqcli -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Output '=== SWITCH TO G1GC ==='
$f = 'C:\StrategyQuantX145\sqcli.config'
Copy-Item $f ($f + '.bak-g1-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
(Get-Content $f) -replace 'option -XX:\+UseParallelGC', 'option -XX:+UseG1GC' | Set-Content -Path $f -Encoding ASCII
$s = 'C:\StrategyQuantX145\user\settings\settings.xml'
Copy-Item $s ($s + '.bak-g1-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
(Get-Content $s -Raw) -replace '<GCType>ParallelGC</GCType>', '<GCType>G1GC</GCType>' | Set-Content -Path $s -Encoding UTF8
Get-Content $f | Select-String 'Xm|GC|Always' | ForEach-Object { Write-Output $_.Line.Trim() }
Get-Content $s | Select-String 'GCType' | ForEach-Object { Write-Output $_.Line.Trim() }

Write-Output '=== START / MEASURE ==='
Start-ScheduledTask -TaskName 'SQX145ProjectAtLogon'
Start-Sleep -Seconds 20
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if (-not $p) { Write-Output 'NO_SQCLI_AFTER_G1_START'; return }
$cpu1 = $p.TotalProcessorTime.TotalSeconds
$ws1 = $p.WorkingSet64
$priv1 = $p.PrivateMemorySize64
Start-Sleep -Seconds 60
$p.Refresh()
$cpu2 = $p.TotalProcessorTime.TotalSeconds
$ws2 = $p.WorkingSet64
$priv2 = $p.PrivateMemorySize64
$pct = (($cpu2 - $cpu1) / 60 / [Environment]::ProcessorCount) * 100
Write-Output ('G1 CPU%=' + [math]::Round($pct, 1) + ' WS_MB=' + [math]::Round($ws2 / 1MB) + ' Private_MB=' + [math]::Round($priv2 / 1MB))
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { Write-Output ('API: ' + $_.Exception.Message) }
