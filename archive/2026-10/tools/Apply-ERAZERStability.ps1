$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

function W([string]$t) { Write-Output $t }

W ('Apply ERAZER stability: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '--- POWER ---'
$cmds = @(
    'powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100',
    'powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100',
    'powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL 1',
    'powercfg /setacvalueindex SCHEME_CURRENT 54533251-82BE-4824-96C1-47B60B740D00 BE337238-0D82-4146-A960-4F3749D470C7 2',
    'powercfg /setacvalueindex SCHEME_CURRENT 54533251-82BE-4824-96C1-47B60B740D00 0CC5B647-C1DF-4637-891A-DEC359347B2B 100',
    'powercfg /setactive SCHEME_CURRENT'
)
foreach ($c in $cmds) {
    $o = Invoke-Expression $c 2>&1
    W ($c + ' => ' + (($o | Out-String).Trim()))
}
$powerChecks = @(
    @('Processor min state', '54533251-82BE-4824-96C1-47B60B740D00', '893DEE8E-2BEF-41D5-8E54-9E3F30F44F9F'),
    @('Processor max state', '54533251-82BE-4824-96C1-47B60B740D00', 'BC5038F7-23E0-4960-96DA-33ABAF5935EC'),
    @('Boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B'),
    @('System cooling policy', '54533251-82BE-4824-96C1-47B60B740D00', '94D3A615-A899-4AC5-AE2B-E4D8F634367F')
)
foreach ($x in $powerChecks) {
    $o = powercfg /query SCHEME_CURRENT $x[1] $x[2] 2>$null
    $ac = ($o | Select-String 'Current AC Power Setting Index').ToString().Trim()
    W ($x[0] + ': ' + $ac)
}

W '--- WIFI POWER / ROAMING ---'
try {
    Set-NetAdapterPowerManagement -Name 'WLAN' -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop
    W 'WLAN AllowComputerToTurnOffDevice: Disabled'
} catch { W ('WLAN PM failed: ' + $_.Exception.Message) }
try {
    Set-NetAdapterAdvancedProperty -Name 'WLAN' -DisplayName 'Roaming Aggressiveness' -DisplayValue '1. Lowest' -ErrorAction Stop
    W 'Roaming Aggressiveness: 1. Lowest'
} catch { W ('Roaming set failed: ' + $_.Exception.Message) }

W '--- NETWORK LOCATION / PROFILE ---'
try {
    Set-Service NlaSvc -StartupType Automatic -ErrorAction Stop
    Start-Service NlaSvc -ErrorAction Stop
    W 'NlaSvc: Automatic / Running'
} catch { W ('NlaSvc failed: ' + $_.Exception.Message) }
try {
    Set-NetConnectionProfile -InterfaceAlias 'WLAN' -NetworkCategory Private -ErrorAction Stop
    W 'WLAN network profile: Private'
} catch { W ('Profile set failed: ' + $_.Exception.Message) }

W '--- CRASH DUMPS ---'
try {
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled -Value 7 -Type DWord
    W 'CrashDumpEnabled=7 (automatic)'
} catch { W ('Crash dump set failed: ' + $_.Exception.Message) }

W '--- MOUSE WITHOUT BORDERS PRIORITY ---'
foreach ($p in (Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue)) {
    try { $p.PriorityClass = 'AboveNormal'; W ('MWB PID ' + $p.Id + ' => AboveNormal') }
    catch { W ('MWB PID ' + $p.Id + ' priority failed: ' + $_.Exception.Message) }
}

W '--- PROXY WATCHER ---'
$watcher = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @('pwsh.exe', 'powershell.exe') -and $_.CommandLine -match 'Sync-ProxyWithNetwork' }
if ($watcher) {
    W ('Proxy watcher running: ' + (($watcher | Select-Object -ExpandProperty ProcessId) -join ','))
} else {
    try { Start-ScheduledTask -TaskName 'SyncProxyWithNetwork' -ErrorAction Stop; W 'Proxy watcher started via task' }
    catch { W ('Proxy watcher start failed: ' + $_.Exception.Message) }
}

W '--- VERIFY ---'
Get-Service NlaSvc, WlanSvc, Dhcp, Dnscache -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceAlias, NetworkCategory | Format-Table -AutoSize | Out-String | Write-Output
Get-NetAdapterPowerManagement -Name 'WLAN' -ErrorAction SilentlyContinue |
    Select-Object Name, AllowComputerToTurnOffDevice | Format-Table -AutoSize | Out-String | Write-Output
Get-NetAdapterAdvancedProperty -Name 'WLAN' -DisplayName 'Roaming Aggressiveness' -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, DisplayValue | Format-Table -AutoSize | Out-String | Write-Output
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled |
    Select-Object CrashDumpEnabled | Format-List | Out-String | Write-Output
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass | Format-Table -AutoSize | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
(Get-ScheduledTask -TaskName 'SyncProxyWithNetwork' -ErrorAction SilentlyContinue).State | Write-Output
