$out = 'C:\Users\Vic\Desktop\sqx-close-result.txt'
$result = 'UNKNOWN'
try {
    $targets = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.Name -like 'StrategyQuant*' })
    if ($targets.Count -eq 0) {
        $targets = @(Get-Process StrategyQuantX_ui -ErrorAction SilentlyContinue)
    }
    if ($targets.Count -eq 0) {
        $result = 'NO_PROCESS'
    } else {
        foreach ($t in $targets) {
            try { [void]$t.CloseMainWindow() } catch { }
        }
        Start-Sleep -Seconds 12
        $alive = @(Get-Process StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue)
        if ($alive.Count -eq 0) {
            $result = 'CLOSED'
        } else {
            $names = $alive | ForEach-Object { "$($_.Name)($($_.Id))" }
            $result = 'STILL_RUNNING:' + ($names -join ',')
        }
    }
} catch {
    $result = 'ERROR: ' + $_.Exception.Message
}
$result | Set-Content -LiteralPath $out -Encoding UTF8
