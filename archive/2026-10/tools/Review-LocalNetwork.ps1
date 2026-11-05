$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\tools\local-network-review.txt'
$lines = New-Object System.Collections.Generic.List[string]
function W([string]$t) { $script:lines.Add($t) }
function Section([string]$t) { W ''; W ('=== ' + $t + ' ===') }
function Add-Table([string]$t, $obj) {
    W ''; W ('--- ' + $t + ' ---')
    if ($null -ne $obj) {
        ($obj | Format-Table -AutoSize -Wrap | Out-String -Width 220).TrimEnd().Split("`n") |
            ForEach-Object { W $_ }
    } else { W '(none)' }
}

W ('Local PC network review: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Section 'SYSTEM'
$os = Get-CimInstance Win32_OperatingSystem
W ('OS: ' + $os.Caption + ' ' + $os.Version + ' build ' + $os.BuildNumber + ' | uptime ' + ((Get-Date) - $os.LastBootUpTime))
$cpu = Get-CimInstance Win32_Processor
W ('CPU: ' + $cpu.Name + ' | logical ' + $cpu.NumberOfLogicalProcessors)

Section 'ADAPTERS / IP'
Add-Table 'Adapters' (Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress)
Add-Table 'IP configuration' (Get-NetIPConfiguration |
    Select-Object InterfaceAlias,
        @{n='IPv4';e={($_.IPv4Address.IPAddress -join ',')}},
        @{n='Gateway';e={($_.IPv4DefaultGateway.NextHop -join ',')}},
        @{n='DNS';e={($_.DNSServer.ServerAddresses -join ',')}})
Add-Table 'Default routes' (Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric)
Add-Table 'IPv4 interfaces / metrics' (Get-NetIPInterface -AddressFamily IPv4 |
    Select-Object InterfaceAlias, IfIndex, InterfaceMetric, AutomaticMetric, Dhcp)
Add-Table 'Connection profile' (Get-NetConnectionProfile | Select-Object Name, InterfaceAlias, NetworkCategory)
W '--- Wi-Fi ---'
(netsh wlan show interfaces) | Select-String 'SSID|BSSID|Signal|Receive rate|Transmit rate|State|Radio type|Authentication' |
    ForEach-Object { W $_.Line.Trim() }
W '--- Wi-Fi driver capabilities ---'
(netsh wlan show drivers) | Select-String 'Hosted network|Radio types|802.11|Wireless Display' |
    ForEach-Object { W $_.Line.Trim() }

Section 'HOTSPOT / ICS'
Add-Table 'Hotspot services' (Get-Service icssvc, SharedAccess, NlaSvc, WlanSvc, Dhcp, Dnscache -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, Status, StartType)
Add-Table '192.168.137.x addresses' (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '192.168.137.*' } | Select-Object InterfaceAlias, IPAddress, PrefixLength)
W '--- Hosted network ---'
(netsh wlan show hostednetwork) | ForEach-Object { W $_ }

Section 'POWER / ADAPTER'
W ((powercfg /getactivescheme) -join ' ')
Add-Table 'Adapter power management' (Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue |
    Select-Object Name, AllowComputerToTurnOffDevice, WakeOnMagicPacket, WakeOnPattern)
Add-Table 'Adapter advanced properties' (Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Power|Sleep|Energy|Roaming|Throughput|Band|802.11|MIMO|U-APSD' } |
    Select-Object Name, DisplayName, DisplayValue)
$s = @(
    @('Sleep idle', '238C9FA8-0AAD-41ED-83F4-97BE242C8F20', '29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA'),
    @('USB selective suspend', '2A737441-1930-4402-8D77-B2BEBBA308A3', '48E6B7A6-50F5-4782-A5D4-53BB8F07E226'),
    @('PCIe ASPM', '501A4D13-42AF-4429-9FD1-A8218C268E20', 'EE12F906-D277-404B-B6DA-E5FA1A576DF5'),
    @('Processor boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B'),
    @('Lid close action', '4F971E89-EEBD-4455-A8DE-9E59040E7347', '5CA83367-6E45-459F-A27B-476B1D01C936')
)
foreach ($x in $s) {
    $o = powercfg /query SCHEME_CURRENT $x[1] $x[2] 2>$null
    $ac = ($o | Select-String 'Current AC Power Setting Index').ToString().Trim()
    $dc = ($o | Select-String 'Current DC Power Setting Index').ToString().Trim()
    W ($x[0] + ': ' + $ac + ' | ' + $dc)
}

Section 'EVENT LOG (last 2 days)'
$since = (Get-Date).AddDays(-2)
$wlan = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WLAN-AutoConfig/Operational'; StartTime=$since; Level=1,2,3} -ErrorAction SilentlyContinue
Add-Table 'WLAN events' ($wlan | Select-Object -First 25 TimeCreated, Id, LevelDisplayName,
    @{n='Message';e={ if ($_.Message) { $_.Message.Substring(0, [Math]::Min(180, $_.Message.Length)) } }})
$sys = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue
Add-Table 'System errors by provider' ($sys | Group-Object ProviderName | Sort-Object Count -Descending |
    Select-Object -First 15 Count, Name)
$net = $sys | Where-Object { $_.ProviderName -match 'Tcpip|Dhcp|Netwtw|rtw|WLAN|DNS|NlaSvc|Kernel-Power' } |
    Select-Object -First 20 TimeCreated, ProviderName, Id, LevelDisplayName,
        @{n='Message';e={ if ($_.Message) { $_.Message.Substring(0, [Math]::Min(180, $_.Message.Length)) } }}
Add-Table 'Network-related system events' $net

$lines | Set-Content -Path $log -Encoding UTF8
Write-Output ('Report saved: ' + $log + ' (' + $lines.Count + ' lines)')
