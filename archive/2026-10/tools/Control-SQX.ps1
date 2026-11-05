param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('status', 'start', 'stop', 'pause', 'resume', 'list', 'start-task', 'start-from-task', 'exit', 'headless', 'gui')]
    [string]$Action,
    [string]$Project = 'S001_reproduce_project',
    [int]$Task = 0
)

$ErrorActionPreference = 'Stop'
$script:ApiBase = 'http://localhost:5050/call?cmd='
$script:GuiTask = 'StartTradingAppsAtLogon'
$script:CliTask = 'SQX-CLI'

function Call-Sqx([string]$cmd, [int]$TimeoutSec = 300) {
    $url = $script:ApiBase + ($cmd -replace ' ', '%20')
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec
    return $r.Content
}

function Test-SqxApi {
    try {
        Call-Sqx '-h' 5 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Stop-CliEngine {
    if (Test-SqxApi) {
        try { Call-Sqx "-project action=stop name=$Project" 15 | Out-Null } catch { }
        try { Call-Sqx '-exit' 15 | Out-Null } catch { }
        Start-Sleep -Seconds 5
    }
    Get-Process sqcli -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

switch ($Action) {
    'list' { Call-Sqx '-project action=list' }
    'status' { Call-Sqx "-project action=status name=$Project" }
    'start' { Call-Sqx "-project action=start name=$Project" }
    'stop' { Call-Sqx "-project action=stop name=$Project" }
    'pause' { Call-Sqx "-project action=pause name=$Project" }
    'resume' { Call-Sqx "-project action=resume name=$Project" }
    'start-task' {
        if ($Task -lt 1) { throw 'Task number is required (1-based).' }
        Call-Sqx "-project action=startOnlyTask name=$Project task=$Task"
    }
    'start-from-task' {
        if ($Task -lt 1) { throw 'Task number is required (1-based).' }
        Call-Sqx "-project action=startFromTask name=$Project task=$Task"
    }
    'exit' {
        Stop-CliEngine
        'SQX CLI engine stopped'
    }
    'headless' {
        Get-Process StrategyQuantX_ui, StrategyQuantX -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-ScheduledTask -TaskName $script:CliTask
        $ready = $false
        for ($i = 0; $i -lt 45; $i++) {
            Start-Sleep -Seconds 2
            if (Test-SqxApi) { $ready = $true; break }
        }
        if (-not $ready) { throw 'SQX CLI engine did not become ready on port 5050.' }
        'SQX headless engine ready on http://localhost:5050'
        Call-Sqx '-project action=list'
    }
    'gui' {
        Stop-CliEngine
        Start-ScheduledTask -TaskName $script:GuiTask
        'SQX GUI start requested'
    }
}
