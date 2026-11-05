# Starts StrategyQuant X and optionally MetaTrader 5 on this machine.
# Writes a diagnostic log to %TEMP%\Start-TradingApps.log.
#
#   .\Start-TradingApps.ps1              # SQX 145 only (MT5 not started)
#   .\Start-TradingApps.ps1 -StartMT5    # also start MT5
#   .\Start-TradingApps.ps1 SQX144       # previous build (rollback)
#   .\Start-TradingApps.ps1 Taobao       # strategyquant144taobao build
#
# Existing instances are detected and left alone. Each launch is verified
# and retried once, which covers the startup race seen on 2026-10-18.
param(
    [ValidateSet('SQX145', 'SQX144', 'Taobao')]
    [string]$Sqx = 'SQX145',
    [switch]$StartMT5
)

$log = Join-Path $env:TEMP 'Start-TradingApps.log'
function Log([string]$m) {
    "$(Get-Date -Format o) $m" | Add-Content -Path $log -Encoding UTF8
}

$sessionId = (Get-Process -Id $PID).SessionId
Log "=== start (SQX=$Sqx, session=$sessionId) ==="

function Start-App {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Arguments,
        [string]$ProcessName,
        [int]$WaitSeconds
    )

    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $sessionId }
    if ($running) {
        Log "$Name already running (PID $($running.Id -join ','))"
        return
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        Log "$Name missing: $Path"
        return
    }

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $startParams = @{
                FilePath         = $Path
                WorkingDirectory = (Split-Path -LiteralPath $Path)
                PassThru         = $true
            }
            if ($Arguments) { $startParams['ArgumentList'] = $Arguments }
            $proc = Start-Process @startParams
            Log "$Name launch attempt $attempt -> PID $($proc.Id)"

            for ($tick = 0; $tick -lt ($WaitSeconds * 2); $tick++) {
                Start-Sleep -Milliseconds 500
                if ($proc.HasExited) {
                    Log "$Name exited early (exit code $($proc.ExitCode))"
                    break
                }
                $live = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
                    Where-Object { $_.SessionId -eq $sessionId }
                if ($live) {
                    Log "$Name running (PID $($live.Id -join ','))"
                    return
                }
            }
            Log "$Name not detected within $WaitSeconds s"
        }
        catch {
            Log "$Name error: $($_.Exception.Message)"
        }
        if ($attempt -lt 2) {
            Log "retrying $Name in 5 s"
            Start-Sleep -Seconds 5
        }
    }
    Log "$Name FAILED to start"
}

if ($StartMT5) {
    Start-App 'MetaTrader 5' 'C:\MetaTrader 5 IC Markets Global\terminal64.exe' '/portable' 'terminal64' 30
    Start-Sleep -Seconds 2
} else {
    Log 'Skipping MetaTrader 5 (StartMT5 not set)'
}
if ($Sqx -eq 'Taobao') {
    Start-App 'StrategyQuant X (taobao)' 'C:\strategyquant144taobao\StrategyQuantX.exe' '' 'StrategyQuantX' 90
}
elseif ($Sqx -eq 'SQX144') {
    Start-App 'StrategyQuant X 144' 'C:\StrategyQuantX144\StrategyQuantX.exe' '' 'StrategyQuantX' 90
}
else {
    Start-App 'StrategyQuant X' 'C:\StrategyQuantX145\StrategyQuantX.exe' '' 'StrategyQuantX' 90
}

Log '=== done ==='
