$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$root = 'C:\StrategyQuantX145\user\projects\S001_reproduce_project'
W '--- PROJECT FILES ---'
Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.xml', '.json', '.sqx', '.db', '.properties', '.cfg', '.ini' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 40 FullName, Length, LastWriteTime |
    Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- FILES CONTAINING nasdaq100 ---'
Get-ChildItem $root -Recurse -File -Include '*.xml', '*.json', '*.properties', '*.cfg', '*.ini', '*.txt' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'nasdaq100' -List -ErrorAction SilentlyContinue | Select-Object -First 20 Path |
    ForEach-Object { W ('  ' + $_.Path) }

W '--- PROJECT LOG TAIL ---'
$pl = Get-ChildItem (Join-Path $root 'log') -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) {
    W ('FILE: ' + $pl.FullName + ' modified=' + $pl.LastWriteTime)
    Get-Content $pl.FullName -Tail 12 | ForEach-Object { W ('  ' + $_) }
}

W '--- ENGINE LOG: LATEST TASK START CONTEXT ---'
$el = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($el) {
    W ('FILE: ' + $el.FullName)
    $lines = Get-Content $el.FullName -ErrorAction SilentlyContinue
    $idx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match 'TASK STARTED|Task started|Starting task') { $idx = $i; break }
    }
    if ($idx -ge 0) {
        $from = [Math]::Max(0, $idx - 5)
        $to = [Math]::Min($lines.Count - 1, $idx + 40)
        for ($i = $from; $i -le $to; $i++) { W ('  ' + $lines[$i].Substring(0, [Math]::Min(250, $lines[$i].Length))) }
    } else {
        W '  no TASK STARTED line found in latest engine log'
    }
}
