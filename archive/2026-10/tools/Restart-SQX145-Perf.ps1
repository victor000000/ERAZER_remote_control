param(
    [string]$CoreUsage = '100%'
)

$ProgressPreference = 'SilentlyContinue'
$install = 'C:\StrategyQuantX145'
$api = 'http://localhost:5050/call?cmd='
$logFile = 'C:\Users\Vic\Desktop\sqx145-perf-restart.txt'
Start-Transcript -Path $logFile -Force | Out-Null

function Call-Sqx([string]$cmd, [int]$timeoutSec = 120) {
    $url = $api + ($cmd -replace ' ', '%20')
    try {
        return (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec $timeoutSec).Content
    } catch {
        return $_.Exception.Message
    }
}

# Stop the current project and CLI engine.
Call-Sqx '-project action=stop name=S001_reproduce_project' 40 | Out-Null
Start-Sleep -Seconds 6
Call-Sqx '-exit' 15 | Out-Null
Start-Sleep -Seconds 6
Stop-ScheduledTask -TaskName SQX-CLI -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Get-Process sqcli -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Revise performance settings.
$settings = Join-Path $install 'user\settings\settings.xml'
Copy-Item $settings ($settings + '.bak-perf-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
$enc = [Text.Encoding]::GetEncoding(28591)
$text = $enc.GetString([IO.File]::ReadAllBytes($settings))
$text = [regex]::Replace($text, '<coreUsage>[^<]*</coreUsage>', '<coreUsage>' + $CoreUsage + '</coreUsage>')
$text = [regex]::Replace($text, '<highPriority>[^<]*</highPriority>', '<highPriority>true</highPriority>')
$text = [regex]::Replace($text, '<memoryCleanup>[^<]*</memoryCleanup>', '<memoryCleanup>false</memoryCleanup>')
[IO.File]::WriteAllText($settings, $text, $enc)
Write-Output "coreUsage=$CoreUsage highPriority=true memoryCleanup=false"

# Start the headless engine.
Start-ScheduledTask -TaskName SQX-CLI
$ready = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    $h = Call-Sqx '-h' 5
    if ($h -and $h -notmatch 'CLI not ready' -and $h -match 'Usage') {
        $ready = $true
        break
    }
}
Write-Output ("READY=" + $ready)
if (-not $ready) { Write-Output $h; exit 1 }

# Enforce High priority on the live engine process.
Get-Process sqcli -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $_.PriorityClass = 'High'
        $_.Refresh()
        Write-Output ("PRIORITY=" + $_.PriorityClass)
    } catch {
        Write-Output ("PRIORITY_ERROR=" + $_.Exception.Message)
    }
}

# Show the core/priority startup lines.
$log = Get-ChildItem (Join-Path $install 'user\log\StrategyQuant') -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 400 |
        Select-String -Pattern 'Adjusting used cores|Using: .*cores|High priority|Preparing thread executors' |
        Select-Object -Last 8 |
        ForEach-Object { $_.Line.Substring(0, [Math]::Min(240, $_.Line.Length)) }
}

# Start the S001 project from task 2.
Write-Output '=== START FROM TASK 2 ==='
Call-Sqx '-project action=startFromTask name=S001_reproduce_project task=2' 180

Start-Sleep -Seconds 10
Write-Output '=== STATUS ==='
Call-Sqx '-project action=status name=S001_reproduce_project' 60
Stop-Transcript | Out-Null
