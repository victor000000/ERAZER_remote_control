$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$db = 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\databanks\databank1_S001_use_nasdaq100'
$start = Get-Date '2026-10-19 06:44:46'
$files = Get-ChildItem $db -File -Filter '*.sqx' -ErrorAction SilentlyContinue
$before = @($files | Where-Object { $_.LastWriteTime -lt $start })
$after = @($files | Where-Object { $_.LastWriteTime -ge $start })
W ('databank1 total=' + @($files).Count + ' beforeTaskStart=' + $before.Count + ' afterTaskStart=' + $after.Count)
W ('oldest=' + (($files | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime) + ' newest=' + (($files | Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime))

W '--- LOG SEARCH: full / restart / finished ---'
$logs = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter '*.log' -ErrorAction SilentlyContinue
foreach ($l in ($logs | Sort-Object LastWriteTime -Descending | Select-Object -First 12)) {
    $hits = Get-Content $l.FullName -ErrorAction SilentlyContinue |
        Select-String -Pattern 'full|restart|finished|MaxStrategies|stopped' -CaseSensitive:$false
    if ($hits) {
        W ('FILE ' + $l.Name + ' modified=' + $l.LastWriteTime)
        $hits | Select-Object -Last 8 | ForEach-Object { W ('  ' + $_.Line.Substring(0, [Math]::Min(220, $_.Line.Length))) }
    }
}
