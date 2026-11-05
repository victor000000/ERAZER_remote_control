$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- STOP PROJECT ---'
try {
    $r = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=stop%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 60
    W $r.Content
} catch { W ('stop error: ' + $_.Exception.Message) }

Start-Sleep -Seconds 8
W '--- STATUS AFTER STOP ---'
try {
    $r2 = Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30
    W $r2.Content
} catch { W ('status error: ' + $_.Exception.Message) }

W '--- PROJECT LOG TAIL ---'
$pl = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) { Get-Content $pl.FullName -Tail 8 | ForEach-Object { W ('  ' + $_) } }

W '--- PROCESS ---'
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if ($p) { W ('sqcli still running pid=' + $p.Id) } else { W 'sqcli exited' }
