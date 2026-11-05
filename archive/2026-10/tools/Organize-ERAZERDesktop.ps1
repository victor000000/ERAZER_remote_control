$ProgressPreference = 'SilentlyContinue'

$base = 'C:\Users\Vic\ERAZER-Tools'
$desk = 'C:\Users\Vic\Desktop'
$dirs = @('Startup', 'Proxy', 'SQX', 'MT5', 'Logs', 'Backups', 'Misc')
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $base $d) | Out-Null
}

Start-Transcript -Path (Join-Path $base 'Logs\organize.log') -Force | Out-Null

function Move-One([string]$name, [string]$destDir) {
    $src = Join-Path $desk $name
    if (Test-Path -LiteralPath $src) {
        Move-Item -LiteralPath $src -Destination (Join-Path $destDir $name) -Force
        Write-Output ("moved: " + $name + " -> " + $destDir)
    }
}

# Stop the proxy watcher before moving its files.
Stop-ScheduledTask -TaskName 'SyncProxyWithNetwork' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'Sync-ProxyWithNetwork\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1

$startup = Join-Path $base 'Startup'
$proxy   = Join-Path $base 'Proxy'
$sqx     = Join-Path $base 'SQX'
$mt5     = Join-Path $base 'MT5'
$logs    = Join-Path $base 'Logs'
$back    = Join-Path $base 'Backups'
$misc    = Join-Path $base 'Misc'

# Startup
Move-One 'Start-TradingApps.ps1' $startup
Move-One 'Start-TradingApps.cmd' $startup

# Proxy
Move-One 'Sync-ProxyWithNetwork.ps1' $proxy
Move-One 'Sync-ProxyWithNetwork.vbs' $proxy
Move-One 'Sync-ProxyWithNetwork.cmd' $proxy
Move-One 'proxy-watch.log' $proxy

# SQX tools
$sqxFiles = @(
    'Start-SQXCLI.vbs', 'Control-SQX.ps1', 'Control-SQX.cmd', 'Close-SQX.ps1',
    'Rebuild-SQXProject.ps1', 'Migrate-SQXData.ps1', 'Activate-SQX145.ps1',
    'Dump-SQXLicense.py', 'Check-SQX145.ps1', 'Check-SQX145-Project.ps1',
    'Inspect-SQX145-Perf.ps1', 'Restart-SQX145-Perf.ps1', 'Start-SQX145PerfTask.ps1',
    'Start-SQX145-Project.cmd', 'Start-SQX145ProjectTask.ps1', 'Test-SQX145List.cmd',
    'Set-PhoneProfileManual.ps1', 'Fix-ERAZERNetwork.ps1'
)
foreach ($n in $sqxFiles) { Move-One $n $sqx }

# MT5 / MWB helpers
foreach ($n in @('Close-MT5.ps1', 'Close-MT5.cmd', 'Focus-MT5.ps1', 'Focus-MT5.cmd', 'Start-MWB.cmd')) {
    Move-One $n $mt5
}

# Misc
Move-One 'Repair-SSH.cmd' $misc

# Logs and results
$logFiles = @(
    'sqx-close-result.txt', 'sqx-windows.txt', 'sqcli-help.txt', 'sqx-cli-start.log',
    'sqx-cli-start.err.log', 'sqx145-activate-result.txt', 'sqx145-perf-restart.txt',
    'network-fix.txt', 'sqx145-list.txt', 'sqx145-project-start.txt',
    'focus-mt5.txt', 'mt5-close.txt'
)
foreach ($n in $logFiles) { Move-One $n $logs }

# Old backups and staging files
Get-ChildItem -LiteralPath $desk -File -Filter '*.bak*' -ErrorAction SilentlyContinue |
    Move-Item -Destination $back -Force
foreach ($n in @('S001_reproduce_project_patched.cfx', 'project_rebuilt.cfx', 'S001_145.cfx')) {
    Move-One $n $back
}

# Update internal paths in the moved scripts.
function Replace-InFile([string]$path, [string]$old, [string]$new) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $enc = [Text.Encoding]::GetEncoding(28591)
    $text = $enc.GetString([IO.File]::ReadAllBytes($path))
    $updated = $text.Replace($old, $new)
    if ($updated -ne $text) {
        [IO.File]::WriteAllText($path, $updated, $enc)
        Write-Output ("updated path: " + $path)
    }
}

$proxyVbs = Join-Path $proxy 'Sync-ProxyWithNetwork.vbs'
Replace-InFile $proxyVbs 'C:\Users\Vic\Desktop\Sync-ProxyWithNetwork.ps1' (Join-Path $proxy 'Sync-ProxyWithNetwork.ps1')

$projectCmd = Join-Path $sqx 'Start-SQX145-Project.cmd'
Replace-InFile $projectCmd 'C:\Users\Vic\Desktop\sqx145-project-start.txt' (Join-Path $logs 'sqx145-project-start.txt')

$projectTask = Join-Path $sqx 'Start-SQX145ProjectTask.ps1'
Replace-InFile $projectTask 'C:\Users\Vic\Desktop\Start-SQX145-Project.cmd' (Join-Path $sqx 'Start-SQX145-Project.cmd')

$perfRestart = Join-Path $sqx 'Restart-SQX145-Perf.ps1'
Replace-InFile $perfRestart 'C:\Users\Vic\Desktop\sqx145-perf-restart.txt' (Join-Path $logs 'sqx145-perf-restart.txt')

$activate = Join-Path $sqx 'Activate-SQX145.ps1'
Replace-InFile $activate 'C:\Users\Vic\Desktop\sqx145-activate-result.txt' (Join-Path $logs 'sqx145-activate-result.txt')

$check = Join-Path $sqx 'Check-SQX145.ps1'
Replace-InFile $check 'C:\Users\Vic\Desktop\Start-SQXCLI.vbs' (Join-Path $sqx 'Start-SQXCLI.vbs')

$fix = Join-Path $sqx 'Fix-ERAZERNetwork.ps1'
Replace-InFile $fix 'C:\Users\Vic\Desktop\network-fix.txt' (Join-Path $logs 'network-fix.txt')

$closeSqx = Join-Path $sqx 'Close-SQX.ps1'
Replace-InFile $closeSqx 'C:\Users\Vic\Desktop\sqx-close-result.txt' (Join-Path $logs 'sqx-close-result.txt')

$focus = Join-Path $mt5 'Focus-MT5.ps1'
Replace-InFile $focus 'C:\Users\Vic\Desktop\focus-mt5.txt' (Join-Path $mt5 'focus-mt5.txt')
$close = Join-Path $mt5 'Close-MT5.ps1'
Replace-InFile $close 'C:\Users\Vic\Desktop\mt5-close.txt' (Join-Path $mt5 'mt5-close.txt')

# Update scheduled tasks.
$startupCmd = Join-Path $startup 'Start-TradingApps.cmd'
$proxyCmd = Join-Path $proxy 'Sync-ProxyWithNetwork.cmd'
$sqxVbs = Join-Path $sqx 'Start-SQXCLI.vbs'

try {
    Set-ScheduledTask -TaskName 'StartTradingAppsAtLogon' -Action (New-ScheduledTaskAction -Execute $startupCmd) | Out-Null
    Write-Output "task updated: StartTradingAppsAtLogon -> $startupCmd"
} catch { Write-Output ("task update failed StartTradingAppsAtLogon: " + $_.Exception.Message) }

try {
    Set-ScheduledTask -TaskName 'SyncProxyWithNetwork' -Action (New-ScheduledTaskAction -Execute $proxyCmd) | Out-Null
    Write-Output "task updated: SyncProxyWithNetwork -> $proxyCmd"
} catch { Write-Output ("task update failed SyncProxyWithNetwork: " + $_.Exception.Message) }

try {
    $a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B "' + $sqxVbs + '"')
    Set-ScheduledTask -TaskName 'SQX-CLI' -Action $a | Out-Null
    Write-Output "task updated: SQX-CLI -> $sqxVbs"
} catch { Write-Output ("task update failed SQX-CLI: " + $_.Exception.Message) }

Unregister-ScheduledTask -TaskName 'SQX145PerfRestart' -Confirm:$false -ErrorAction SilentlyContinue

# Desktop shortcut to the tools folder.
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $desk 'ERAZER Tools.lnk'))
$lnk.TargetPath = $base
$lnk.Save()

# Restart the proxy watcher with the new paths.
Start-ScheduledTask -TaskName 'SyncProxyWithNetwork'

# Verification.
Write-Output '=== DESKTOP ==='
Get-ChildItem -LiteralPath $desk | Select-Object Name, Mode, Length | Format-Table -AutoSize
Write-Output '=== TASKS ==='
Get-ScheduledTask -TaskName 'StartTradingAppsAtLogon', 'SyncProxyWithNetwork', 'SQX-CLI' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State, @{n='Action';e={$_.Actions | Out-String}} |
    Format-List
Write-Output '=== TOOLS TREE ==='
Get-ChildItem -LiteralPath $base -Directory | ForEach-Object {
    Write-Output ("--- " + $_.Name + " ---")
    Get-ChildItem -LiteralPath $_.FullName -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
}

# Move the organizer and its starter off the desktop too.
Move-One 'Organize-ERAZERDesktop.ps1' $misc
Move-One 'Start-OrganizeTask.ps1' $misc

Stop-Transcript | Out-Null
