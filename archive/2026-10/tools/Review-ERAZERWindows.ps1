$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\windows-review.txt'
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
function Add-List([string]$t, $obj) {
    W ''; W ('--- ' + $t + ' ---')
    if ($null -ne $obj) {
        ($obj | Format-List | Out-String -Width 220).TrimEnd().Split("`n") |
            ForEach-Object { W $_ }
    } else { W '(none)' }
}
function Try-Block([string]$label, [scriptblock]$sb) {
    try { & $sb } catch { W ('ERROR ' + $label + ': ' + $_.Exception.Message) }
}

W ('Windows review: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

Section 'SYSTEM'
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
W ('OS: ' + $os.Caption + ' | Version ' + $os.Version + ' | Build ' + $os.BuildNumber)
W ('Computer: ' + $cs.Manufacturer + ' ' + $cs.Model + ' | RAM ' + [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) + ' GB')
W ('CPU: ' + $cpu.Name + ' | Cores ' + $cpu.NumberOfCores + ' | Logical ' + $cpu.NumberOfLogicalProcessors)
W ('Last boot: ' + $os.LastBootUpTime + ' | Uptime: ' + ((Get-Date) - $os.LastBootUpTime).ToString())
Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[C-Z]$' } |
    ForEach-Object { W ('Drive ' + $_.Name + ': used ' + [math]::Round($_.Used / 1GB, 1) + ' GB / free ' + [math]::Round($_.Free / 1GB, 1) + ' GB') }
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
    ForEach-Object { W ('PageFile: ' + $_.Name + ' Allocated ' + $_.AllocatedBaseSize + ' MB Peak ' + $_.PeakUsage + ' MB') }

Section 'POWER'
W ((powercfg /getactivescheme) -join ' ')
W 'Available sleep states:'
(powercfg /a) | ForEach-Object { W $_ }
$hiber = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled, HibernateEnabled -ErrorAction SilentlyContinue
W ('Fast startup HiberbootEnabled=' + $hiber.HiberbootEnabled + ' HibernateEnabled=' + $hiber.HibernateEnabled)
$settings = @(
    @('Sleep idle', '238C9FA8-0AAD-41ED-83F4-97BE242C8F20', '29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA'),
    @('Display idle', '7516B95F-F776-4464-8C53-06167F40CC99', '3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E'),
    @('USB selective suspend', '2A737441-1930-4402-8D77-B2BEBB A308A3'.Replace(' ', ''), '48E6B7A6-50F5-4782-A5D4-53BB8F07E226'),
    @('PCIe ASPM', '501A4D13-42AF-4429-9FD1-A8218C268E20', 'EE12F906-D277-404B-B6DA-E5FA1A576DF5'),
    @('Processor boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B')
)
foreach ($s in $settings) {
    $o = powercfg /query SCHEME_CURRENT $s[1] $s[2] 2>$null
    $ac = ($o | Select-String 'Current AC Power Setting Index').ToString().Trim()
    $dc = ($o | Select-String 'Current DC Power Setting Index').ToString().Trim()
    W ($s[0] + ': ' + $ac + ' | ' + $dc)
}
$ve = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -ErrorAction SilentlyContinue
W ('VisualFXSetting=' + $ve.VisualFXSetting + ' (2=best performance)')

Section 'NETWORK'
Add-Table 'Adapters' (Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress)
Add-Table 'IP configuration' (Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Select-Object InterfaceAlias,
        @{n='IPv4';e={($_.IPv4Address.IPAddress -join ',')}},
        @{n='Gateway';e={($_.IPv4DefaultGateway.NextHop -join ',')}},
        @{n='DNS';e={($_.DNSServer.ServerAddresses -join ',')}})
Add-Table 'Default routes' (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric)
Add-Table 'Connection profile' (Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceAlias, NetworkCategory)
W '--- Wi-Fi ---'
(netsh wlan show interfaces) | Select-String 'SSID|Signal|Receive rate|Transmit rate|State|Radio type|Authentication' |
    ForEach-Object { W $_.Line.Trim() }
Add-Table 'Adapter power management' (Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue |
    Select-Object Name, AllowComputerToTurnOffDevice, WakeOnMagicPacket, WakeOnPattern)
Add-Table 'Adapter advanced properties' (Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Power|Sleep|Energy|Roaming|Throughput|Band|802.11' } |
    Select-Object Name, DisplayName, DisplayValue)
$proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
W ('WinINET proxy: Enable=' + $proxy.ProxyEnable + ' Server=' + $proxy.ProxyServer + ' Override=' + $proxy.ProxyOverride)
W 'WinHTTP proxy:'
(netsh winhttp show proxy) | ForEach-Object { W $_ }

Section 'SECURITY'
Try-Block 'Defender status' {
    Get-MpComputerStatus | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled,
        AntispywareEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled, NISEnabled,
        OnAccessProtectionEnabled, AntivirusSignatureLastUpdated, AMEngineVersion |
        Format-List | Out-String | ForEach-Object { $_.TrimEnd().Split("`n") | ForEach-Object { W $_ } }
}
Try-Block 'Defender preferences' {
    $pr = Get-MpPreference
    W ('DisableRealtimeMonitoring=' + $pr.DisableRealtimeMonitoring + ' DisableIOAVProtection=' + $pr.DisableIOAVProtection +
        ' DisableBehaviorMonitoring=' + $pr.DisableBehaviorMonitoring + ' DisableBlockAtFirstSeen=' + $pr.DisableBlockAtFirstSeen)
    W ('ExclusionPath: ' + ($pr.ExclusionPath -join '; '))
    W ('ExclusionProcess: ' + ($pr.ExclusionProcess -join '; '))
}
Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue |
    ForEach-Object { W ('AV: ' + $_.displayName + ' state=' + $_.productState) }
Add-Table 'Firewall profiles' (Get-NetFirewallProfile -ErrorAction SilentlyContinue |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction)
Add-Table 'Security services' (Get-Service WinDefend, SecurityHealthService, mpssvc -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType)

Section 'WINDOWS UPDATE'
Add-Table 'Update services' (Get-Service wuauserv, BITS, UsoSvc, TrustedInstaller -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType)
Add-Table 'Recent hotfixes' (Get-HotFix -ErrorAction SilentlyContinue |
    Sort-Object InstalledOn -Descending | Select-Object -First 6 HotFixID, Description, InstalledOn)
$wu = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue
W ('WindowsUpdate policy: ' + ($wu | Out-String).Trim())
$au = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue
W ('AU policy: ' + ($au | Out-String).Trim())
foreach ($r in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
                 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')) {
    W ($r + ' = ' + (Test-Path $r))
}

Section 'SERVICES'
$svcNames = 'WSearch,SysMain,DiagTrack,dmwappushservice,Spooler,Fax,RemoteRegistry,WMPNetworkSvc,WalletService,MapsBroker,PhoneSvc,SSDPSRV,upnphost,BTAGService,bthserv,BthAvrcpTg,XblAuthManager,XblGameSave,XboxGipSvc,XboxNetApiSvc,GameInputSvc,WerSvc,w32time,WinDefend,mpssvc,wuauserv,BITS,UsoSvc,Schedule,EventLog,Winmgmt,RpcSs,Dnscache,Dhcp,WlanSvc,NlaSvc,TermService,SessionEnv,UmRdpService,SharedAccess,icssvc,iphlpsvc,Audiosrv,AudioEndpointBuilder,Themes,seclogon,RemoteAccess,SNMPTRAP,lanmanserver,lanmanworkstation'
Add-Table 'Curated services' (Get-Service -Name ($svcNames -split ',') -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, Status, StartType | Sort-Object Name)
Add-Table 'Non-Microsoft auto services' (Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.StartMode -in @('Auto', 'Automatic') -and $_.PathName -notmatch 'C:\\Windows\\' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Sort-Object Name)

Section 'STARTUP'
Add-Table 'Startup commands' (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Select-Object Name, Command, Location, User)
$runPaths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
              'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
              'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
foreach ($p in $runPaths) {
    $it = Get-ItemProperty $p -ErrorAction SilentlyContinue
    if ($it) {
        W ('--- ' + $p + ' ---')
        $it.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } |
            ForEach-Object { W ($_.Name + ' = ' + $_.Value) }
    }
}
foreach ($d in @('C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp',
                 (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'))) {
    W ('--- ' + $d + ' ---')
    Get-ChildItem $d -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { W $_ }
}

Section 'SCHEDULED TASKS'
Add-Table 'Non-Microsoft tasks' (Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
    Select-Object TaskName, TaskPath, State | Sort-Object TaskPath, TaskName)
$msPaths = @('\Microsoft\Windows\Application Experience\', '\Microsoft\Windows\Customer Experience Improvement Program\',
             '\Microsoft\Windows\Feedback\', '\Microsoft\Windows\DiskDiagnostic\', '\Microsoft\Windows\Maintenance\')
Add-Table 'Microsoft telemetry/maintenance tasks' (Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $p = $_.TaskPath; $msPaths | Where-Object { $p -like ($_ + '*') } } |
    Select-Object TaskName, TaskPath, State)

Section 'APPX / STORE APPS'
$apps = Get-AppxPackage -ErrorAction SilentlyContinue
W ('Installed Appx count: ' + $apps.Count)
$consumer = @('*Xbox*', '*Solitaire*', '*Bing*', '*Weather*', '*News*', '*Maps*', '*People*', '*Skype*',
              '*Teams*', '*Clipchamp*', '*Feedback*', '*GetHelp*', '*GetStart*', '*Tips*', '*Phone*',
              '*Cortana*', '*MixedReality*', '*OfficeHub*', '*OneDrive*', '*Zune*', '*Groove*',
              '*SoundRecorder*', '*Camera*', '*Photos*', '*StickyNotes*', '*Copilot*')
$cons = $apps | Where-Object { $n = $_.Name; $consumer | Where-Object { $n -like $_ } }
Add-Table 'Consumer Appx' ($cons | Select-Object Name, Version, Status | Sort-Object Name)

Section 'INSTALLED PROGRAMS (non-Microsoft)'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.Publisher -notmatch 'Microsoft' } |
    Select-Object DisplayName, Publisher, DisplayVersion, InstallDate |
    Sort-Object DisplayName -Unique |
    ForEach-Object { W ($_.DisplayName + ' | ' + $_.Publisher + ' | ' + $_.DisplayVersion) }

Section 'WINDOWS FEATURES'
$feat = 'SMB1Protocol', 'Internet-Explorer-Optional-amd64', 'WindowsMediaPlayer', 'Microsoft-Hyper-V-All',
        'VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux', 'Containers-DisposableClientVM',
        'MicrosoftWindowsPowerShellV2Root', 'TelnetClient', 'TFTP', 'WorkFolders-Client', 'FaxService',
        'Printing-Foundation-Features', 'Windows-Defender-ApplicationGuard', 'Windows-Search'
foreach ($f in $feat) {
    $x = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
    if ($x) { W ($f + ': ' + $x.State) }
}

Section 'TIME'
Add-Table 'Time service' (Get-Service w32time -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType)
W ((w32tm /query /status 2>&1) -join ' ')
(w32tm /query /configuration 2>&1 | Select-String 'Type:|NtpServer:|Enabled:') | ForEach-Object { W $_.Line }

Section 'EVENT LOG ERRORS (last 7 days)'
$since = (Get-Date).AddDays(-7)
$sys = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue
Add-Table 'System errors by provider' ($sys | Group-Object ProviderName | Sort-Object Count -Descending |
    Select-Object -First 15 Count, Name)
$key = $sys | Where-Object { $_.ProviderName -match 'WHEA|Kernel-Power|Disk|Ntfs|Netwtw|Tcpip|Service Control Manager|volmgr' } |
    Select-Object -First 20 TimeCreated, ProviderName, Id, LevelDisplayName,
        @{n='Message';e={ if ($_.Message) { $_.Message.Substring(0, [Math]::Min(160, $_.Message.Length)) } }}
Add-Table 'Key system events' $key
Add-Table 'Minidumps' (Get-ChildItem 'C:\Windows\Minidump' -ErrorAction SilentlyContinue |
    Select-Object Name, Length, LastWriteTime)
$crash = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -ErrorAction SilentlyContinue
W ('CrashDumpEnabled=' + $crash.CrashDumpEnabled + ' (0 none, 1 complete, 2 kernel, 3 small, 7 automatic)')

Section 'STORAGE'
Add-Table 'Physical disks' (Get-PhysicalDisk -ErrorAction SilentlyContinue |
    Select-Object FriendlyName, MediaType, @{n='SizeGB';e={[math]::Round($_.Size / 1GB)}}, HealthStatus, OperationalStatus)
Try-Block 'Storage reliability' {
    Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop |
        Select-Object DeviceId, Wear, ReadErrors, WriteErrors, Temperature, PowerOnHours |
        Format-List | Out-String | ForEach-Object { $_.TrimEnd().Split("`n") | ForEach-Object { W $_ } }
}

Section 'TRADING / REMOTE'
Add-Table 'Processes' (Get-Process sqcli, terminal64, StrategyQuantX, rustdesk, MouseWithoutBorders, copilotapp -ErrorAction SilentlyContinue |
    Select-Object Name, Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}})
Add-Table 'Key services' (Get-Service sshd, MouseWithoutBordersSvc, RustDesk -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType)
Add-Table 'Key scheduled tasks' (Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -match 'SQX|Trading|Proxy|MWB|RustDesk|Start|Organize' } |
    Select-Object TaskName, TaskPath, State)

$lines | Set-Content -Path $log -Encoding UTF8
Write-Output ('Report saved: ' + $log + ' (' + $lines.Count + ' lines)')
