$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- PROJECT ROOT FILES ---'
foreach ($d in @('C:\StrategyQuantX145\user\projects\S001_reproduce_project',
                 'C:\StrategyQuantX145\user\projects')) {
    W ('DIR ' + $d)
    Get-ChildItem $d -Force -ErrorAction SilentlyContinue |
        Select-Object Mode, Length, LastWriteTime, Name | Format-Table -AutoSize | Out-String -Width 160 | Write-Output
}

W '--- PROJECT DEFINITION CANDIDATES (parent) ---'
Get-ChildItem 'C:\StrategyQuantX145\user\projects' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -notin '.sqx' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 40 FullName, Length, LastWriteTime |
    Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- API PROBES ---'
foreach ($cmd in @('-project%20action=list',
                   '-project%20action=info%20name=S001_reproduce_project',
                   '-task%20action=list%20project=S001_reproduce_project',
                   '-task%20action=status%20project=S001_reproduce_project',
                   '-help')) {
    W ('CMD ' + $cmd)
    try {
        $r = Invoke-WebRequest ('http://localhost:5050/call?cmd=' + $cmd) -UseBasicParsing -TimeoutSec 15
        W ($r.Content.Substring(0, [Math]::Min(800, $r.Content.Length)))
    } catch {
        W ('  error: ' + $_.Exception.Message)
    }
}
