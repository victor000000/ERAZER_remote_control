$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('Fix WLAN: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

# Wireless Adapter Settings -> Power Saving Mode = Maximum Performance (AC)
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>&1 | Out-Null
powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
W 'Wireless power saving mode (AC): 0 (Maximum Performance)'

# Disable adapter power management (allow computer to turn off device)
try {
    Disable-NetAdapterPowerManagement -Name 'WLAN' -ErrorAction Stop
    W 'Disable-NetAdapterPowerManagement: ok'
} catch { W ('Disable-NetAdapterPowerManagement failed: ' + $_.Exception.Message) }

# Also clear the WMI power-off flag if present
try {
    $wl = Get-NetAdapter -Name 'WLAN' -ErrorAction Stop
    $mp = Get-CimInstance -Namespace root\WMI -ClassName MSPower_DeviceEnable -ErrorAction Stop |
        Where-Object { $_.InstanceName -eq $wl.PnPDeviceID -or $_.InstanceName -like ('*' + $wl.PnPDeviceID + '*') }
    if ($mp) {
        foreach ($m in $mp) {
            if ($m.Enable) {
                Set-CimInstance -InputObject $m -Property @{ Enable = $false } -ErrorAction Stop
                W ('MSPower_DeviceEnable disabled for ' + $m.InstanceName)
            } else {
                W ('MSPower_DeviceEnable already off for ' + $m.InstanceName)
            }
        }
    } else {
        W 'MSPower_DeviceEnable instance not found'
    }
} catch { W ('MSPower_DeviceEnable failed: ' + $_.Exception.Message) }

# Roaming aggressiveness: valid values are 1. Disable / 2. Lowest / ... / 6. Highest
try {
    Set-NetAdapterAdvancedProperty -Name 'WLAN' -DisplayName 'Roaming Aggressiveness' -DisplayValue '2. Lowest' -ErrorAction Stop
    W 'Roaming Aggressiveness: 2. Lowest'
} catch { W ('Roaming set failed: ' + $_.Exception.Message) }

W '--- POWER INDEX VERIFY ---'
foreach ($x in @(
    @('Min processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN'),
    @('Max processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMAX'),
    @('Boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B'),
    @('System cooling policy', 'SUB_PROCESSOR', 'SYSCOOLPOL'),
    @('Wireless power saving', '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1', '12bbebe6-58d6-4636-95bb-3217ef867c1a')
)) {
    $v = powercfg /getacvalueindex SCHEME_CURRENT $x[1] $x[2] 2>$null
    W ($x[0] + ': ' + (($v | Out-String).Trim()))
}

W '--- WLAN VERIFY ---'
Get-NetAdapterPowerManagement -Name 'WLAN' -ErrorAction SilentlyContinue |
    Select-Object Name, AllowComputerToTurnOffDevice | Format-List | Out-String | Write-Output
Get-NetAdapterAdvancedProperty -Name 'WLAN' -DisplayName 'Roaming Aggressiveness' -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, DisplayValue | Format-List | Out-String | Write-Output
Get-NetAdapterAdvancedProperty -Name 'WLAN' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, DisplayValue | Format-Table -AutoSize | Out-String | Write-Output

W '--- SQX ---'
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
