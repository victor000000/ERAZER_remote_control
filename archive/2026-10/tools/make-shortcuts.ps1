$w = New-Object -ComObject WScript.Shell
$defs = @(
    @{ Name = 'MetaTrader 5.lnk';                  Target = 'C:\MetaTrader 5 IC Markets Global\terminal64.exe'; Args = '/portable'; Dir = 'C:\MetaTrader 5 IC Markets Global' },
    @{ Name = 'StrategyQuant X.lnk';               Target = 'C:\StrategyQuantX144\StrategyQuantX.exe';          Args = '';         Dir = 'C:\StrategyQuantX144' },
    @{ Name = 'StrategyQuant X (taobao).lnk';      Target = 'C:\strategyquant144taobao\StrategyQuantX.exe';     Args = '';         Dir = 'C:\strategyquant144taobao' }
)
foreach ($d in $defs) {
    $path = Join-Path 'C:\Users\Vic\Desktop' $d.Name
    $s = $w.CreateShortcut($path)
    $s.TargetPath = $d.Target
    $s.Arguments = $d.Args
    $s.WorkingDirectory = $d.Dir
    $s.Save()
    Write-Output $path
}
