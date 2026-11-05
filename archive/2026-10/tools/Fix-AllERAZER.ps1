$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\fix-all.txt'
function W([string]$t) { Write-Output $t }

W ('Fix all ERAZER: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '=== DEFENDER EXCLUSIONS / REAL-TIME ==='
$exPaths = @('C:\StrategyQuantX145', 'C:\Users\Vic\AppData\Roaming\MetaQuotes', 'C:\Users\Vic\ERAZER-Tools')
foreach ($dir in @('C:\', 'C:\Program Files', 'C:\Program Files (x86)')) {
    Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'MetaTrader|MT5' } |
        ForEach-Object { $exPaths += $_.FullName }
}
$exPaths = $exPaths | Select-Object -Unique
foreach ($p in $exPaths) {
    if (Test-Path $p) {
        Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue
        W ('exclusion path: ' + $p)
    }
}
Add-MpPreference -ExclusionProcess 'terminal64.exe', 'StrategyQuantX.exe', 'sqcli.exe' -ErrorAction SilentlyContinue
W 'exclusion processes: terminal64.exe, StrategyQuantX.exe, sqcli.exe'
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object RealTimeProtectionEnabled, AntivirusEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled |
    Format-List | Out-String | Write-Output
Get-MpPreference -ErrorAction SilentlyContinue |
    Select-Object DisableRealtimeMonitoring, ExclusionPath, ExclusionProcess |
    Format-List | Out-String | Write-Output

W '=== APPX CLEANUP ==='
$names = @(
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.Microsoft3DViewer', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftStickyNotes', 'Microsoft.MixedReality.Portal', 'Microsoft.SkypeApp',
    'Microsoft.Todos', 'Microsoft.Windows.PeopleExperienceHost', 'Microsoft.Windows.Photos',
    'Microsoft.WindowsCamera', 'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps',
    'Microsoft.WindowsSoundRecorder', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxGameCallableUI',
    'Microsoft.XboxGamingOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'MSTeams', 'Clipchamp.Clipchamp',
    'microsoft.windowscommunicationsapps', 'MicrosoftWindows.Client.WebExperience', 'MicrosoftWindows.Client.AIX'
)
foreach ($n in $names) {
    $pkgs = Get-AppxPackage -Name $n -AllUsers -ErrorAction SilentlyContinue
    foreach ($p in $pkgs) {
        try {
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
            W ('removed appx: ' + $p.PackageFullName)
        } catch { W ('appx remove failed ' + $p.PackageFullName + ': ' + $_.Exception.Message) }
    }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.PackageName -eq $n }
    foreach ($pp in $prov) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop
            W ('unprovisioned: ' + $pp.PackageName)
        } catch { W ('unprovision failed ' + $pp.PackageName + ': ' + $_.Exception.Message) }
    }
}
W ('Appx count now: ' + (Get-AppxPackage -ErrorAction SilentlyContinue).Count)

W '=== CONSUMER / WIDGETS / GAME BAR ==='
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarDa -Value 0 -Type DWord
New-Item 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Value 1 -Type DWord
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Value 1 -Type DWord
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
New-Item $cdm -Force | Out-Null
foreach ($n in 'SubscribedContent-338389Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled') {
    Set-ItemProperty $cdm -Name $n -Value 0 -Type DWord
}
New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -Value 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AllowAutoGameMode -Value 0 -Type DWord
New-Item 'HKCU:\System\GameConfigStore' -Force | Out-Null
Set-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled -Value 0 -Type DWord
W 'consumer features, widgets, tips, game bar disabled'

W '=== EDGE / ONEDRIVE / TELEMETRY TASKS ==='
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'MicrosoftEdgeAutoLaunch_D47F3D1B73A3FC758D3378FB5F1F17F1' -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName 'MicrosoftEdgeUpdateTaskMachine*' -ErrorAction SilentlyContinue |
    Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
Get-ScheduledTask -TaskName 'OneDrive Standalone Update Task*' -ErrorAction SilentlyContinue |
    Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
foreach ($k in @('Registry::HKEY_USERS\S-1-5-19\Software\Microsoft\Windows\CurrentVersion\Run',
                 'Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\Run')) {
    Remove-ItemProperty -Path $k -Name OneDriveSetup -ErrorAction SilentlyContinue
    W ('OneDriveSetup cleared: ' + $k)
}
$tasks = @('MareBackup', 'Microsoft Compatibility Appraiser Exp', 'PcaPatchDbTask', 'SdbinstMergeDbTask',
           'StartupAppTask', 'Consolidator', 'UsbCeip', 'Microsoft-Windows-DiskDiagnosticDataCollector',
           'DmClient', 'DmClientOnScenarioDownload', 'WinSAT', 'SoftLandingCreativeManagementTask',
           'SoftLandingDeferralTask-*', 'SoftLandingTriggerTask-*')
foreach ($t in $tasks) {
    Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue |
        Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
}
W 'Edge/OneDrive/telemetry/SoftLanding tasks disabled'

W '=== OEM SERVICES ==='
foreach ($n in @('LISFService', 'PCAppStoreServiceAS', 'BlasoulPcManagerService')) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) {
        Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
        Set-Service -Name $n -StartupType Disabled -ErrorAction SilentlyContinue
        W ('OEM service stopped/disabled: ' + $n)
    } else { W ('OEM service not found: ' + $n) }
}

W '=== MWB SERVICE ==='
Set-Service MouseWithoutBordersSvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue
W ((Get-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue | Out-String).Trim())

W '=== BLUETOOTH / UPnP (not used) ==='
foreach ($n in @('BTAGService', 'bthserv', 'SSDPSRV', 'upnphost')) {
    Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
    Set-Service -Name $n -StartupType Disabled -ErrorAction SilentlyContinue
    W ('disabled: ' + $n)
}

W '=== PAGE FILE 24 GB ==='
try {
    $pf = Get-CimInstance Win32_PageFileSetting -Filter "Name='C:\\pagefile.sys'" -ErrorAction SilentlyContinue
    if (-not $pf) {
        $pf = New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'C:\pagefile.sys' } -ErrorAction Stop
    }
    Set-CimInstance -InputObject $pf -Property @{ InitialSize = 24576; MaximumSize = 24576 } -ErrorAction Stop
    Get-CimInstance Win32_PageFileSetting | Select-Object Name, InitialSize, MaximumSize |
        Format-List | Out-String | Write-Output
    W 'Page file set to 24 GB (applies after reboot)'
} catch { W ('Page file failed: ' + $_.Exception.Message) }

W '=== SQX HEAP 24 GB (next engine start) ==='
foreach ($f in @('C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config')) {
    if (Test-Path $f) {
        Copy-Item $f ($f + '.bak-fixall-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
        $c = Get-Content $f -Raw
        $c = $c -replace '-Xmx28g', '-Xmx24g' -replace '-Xmx29g', '-Xmx24g'
        Set-Content -Path $f -Value $c -Encoding ASCII
        W ('updated heap in ' + $f)
    }
}
Select-String -Path 'C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config' -Pattern 'Xm[sx]' |
    ForEach-Object { W ($_.Path + ': ' + $_.Line.Trim()) }

W '=== VERIFY ==='
Get-Service NlaSvc, MouseWithoutBordersSvc, BTAGService, bthserv, SSDPSRV, upnphost -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
Get-CimInstance Win32_OperatingSystem | ForEach-Object {
    Write-Output ('RAM free MB=' + [math]::Round($_.FreePhysicalMemory / 1KB) + ' / ' + [math]::Round($_.TotalVisibleMemorySize / 1KB))
}
