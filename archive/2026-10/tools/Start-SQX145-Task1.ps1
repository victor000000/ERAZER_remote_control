$ProgressPreference = 'SilentlyContinue'
$exe = 'C:\StrategyQuantX145\sqcli.exe'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\sqx145-task1-start.txt'
$err = $log + '.err'
$args = @('-project', 'action=startFromTask', 'name=S001_reproduce_project', 'task=1')

$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory 'C:\StrategyQuantX145' `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $err

Start-Sleep -Seconds 3
try {
    (Get-Process -Id $p.Id -ErrorAction Stop).PriorityClass = 'High'
} catch {
    Add-Content -Path $err -Value ('priority set failed: ' + $_.Exception.Message)
}

$p.WaitForExit()
