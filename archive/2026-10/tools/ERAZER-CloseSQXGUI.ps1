$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
W ('user=' + $id.Name + ' elevated=' + $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

$gui = Get-Process StrategyQuantX -ErrorAction SilentlyContinue
if ($gui) {
    foreach ($g in $gui) {
        W ('GUI pid=' + $g.Id + ' session=' + $g.SessionId + ' title=[' + $g.MainWindowTitle + ']')
        $closed = $g.CloseMainWindow()
        W ('CloseMainWindow=' + $closed)
    }
    Start-Sleep -Seconds 10
    $still = Get-Process StrategyQuantX -ErrorAction SilentlyContinue
    if ($still) {
        W 'GUI still running; stopping process'
        $still | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
} else {
    W 'GUI not running'
}
W ('GUI now running=' + [bool](Get-Process StrategyQuantX -ErrorAction SilentlyContinue))
W ('sqcli running=' + [bool](Get-Process sqcli -ErrorAction SilentlyContinue))
