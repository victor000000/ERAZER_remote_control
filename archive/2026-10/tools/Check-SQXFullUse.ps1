$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '=== SQX PROCESS / TASK ==='
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if ($p) {
    $p | Select-Object Id, PriorityClass, CPU, @{n='WSMB';e={[math]::Round($_.WorkingSet64/1MB)}}, @{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB)}} |
        Format-List | Out-String | Write-Output
} else { W 'sqcli NOT RUNNING' }
Get-ScheduledTask -TaskName 'SQX145ProjectAtLogon','SQX145Project','StartTradingAppsAtLogon','SQX-CLI' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

W '=== ENGINE CONFIG ==='
Select-String -Path 'C:\StrategyQuantX145\sqcli.config' -Pattern 'Xm[sx]|UseG1GC|UseParallelGC|AlwaysPreTouch|Xmn|GCThreads' |
    ForEach-Object { W $_.Line.Trim() }
Select-String -Path 'C:\StrategyQuantX145\user\settings\settings.xml' -Pattern 'coreUsage|highPriority|memoryCleanup|gpuAccelerated|GCType|threadAffinity|memoryProtection' |
    ForEach-Object { W $_.Line.Trim() }

W '=== API STATUS ==='
try { (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content }
catch { W ('API: ' + $_.Exception.Message) }

if ($p) {
    W '=== 5-MINUTE CPU / MEMORY SAMPLING (10s) ==='
    $cores = [Environment]::ProcessorCount
    $samples = @()
    $prev = $p.TotalProcessorTime.TotalSeconds
    for ($i = 1; $i -le 30; $i++) {
        Start-Sleep -Seconds 10
        $p.Refresh()
        $now = $p.TotalProcessorTime.TotalSeconds
        $pct = (($now - $prev) / 10 / $cores) * 100
        $samples += [pscustomobject]@{ N = $i; CPU = [math]::Round($pct, 1); WSMB = [math]::Round($p.WorkingSet64/1MB); PrivateMB = [math]::Round($p.PrivateMemorySize64/1MB) }
        $prev = $now
        W ('sample ' + $i + ': CPU%=' + [math]::Round($pct, 1) + ' WS_MB=' + [math]::Round($p.WorkingSet64/1MB))
    }
    $st = $samples | Measure-Object -Property CPU -Minimum -Maximum -Average
    W ('CPU stats: min=' + [math]::Round($st.Minimum,1) + ' max=' + [math]::Round($st.Maximum,1) + ' avg=' + [math]::Round($st.Average,1))
    $ws = $samples | Measure-Object -Property WSMB -Minimum -Maximum -Average
    W ('WS stats: min=' + $ws.Minimum + ' max=' + $ws.Maximum + ' avg=' + [math]::Round($ws.Average))
}

W '=== PAGE FILE / RAM ==='
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
    Select-Object AllocatedBaseSize, PeakUsage, CurrentUsage | Format-List | Out-String | Write-Output
Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue |
    ForEach-Object { W ('RAM free MB=' + [math]::Round($_.FreePhysicalMemory/1KB) + ' / ' + [math]::Round($_.TotalVisibleMemorySize/1KB)) }

W '=== POWER ==='
(powercfg /getactivescheme) | ForEach-Object { W $_ }
foreach ($x in @(
    @('Min processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN'),
    @('Max processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMAX'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B'),
    @('Boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7')
)) {
    $o = powercfg /query SCHEME_CURRENT $x[1] $x[2] 2>$null
    $ac = ($o | Select-String 'Current AC Power Setting Index').ToString().Trim()
    W ($x[0] + ': ' + $ac)
}
