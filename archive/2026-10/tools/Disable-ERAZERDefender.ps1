$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\defender-disable.txt'
function W([string]$t) { Write-Output $t }

W ('Disable Defender/Security: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '=== POLICY ==='
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$rt = $pol + '\Real-Time Protection'
New-Item -Path $rt -Force | Out-Null
New-ItemProperty -Path $pol -Name DisableAntiSpyware -Value 1 -PropertyType DWord -Force | Out-Null
foreach ($n in 'DisableRealtimeMonitoring', 'DisableBehaviorMonitoring', 'DisableIOAVProtection',
               'DisableOnAccessProtection', 'DisableScanOnRealtimeEnable', 'DisableScriptScanning') {
    New-ItemProperty -Path $rt -Name $n -Value 1 -PropertyType DWord -Force | Out-Null
    W ('policy set: ' + $n + '=1')
}

W '=== PREFERENCES ==='
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
Get-MpPreference -ErrorAction SilentlyContinue |
    Select-Object DisableRealtimeMonitoring, DisableIOAVProtection, DisableBehaviorMonitoring, DisableBlockAtFirstSeen |
    Format-List | Out-String | Write-Output

W '=== SERVICES ==='
foreach ($svc in @('WinDefend', 'wscsvc', 'SecurityHealthService')) {
    try {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        W ('service stop/disable: ' + $svc)
    } catch { W ('service ' + $svc + ' failed: ' + $_.Exception.Message) }
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $svc
    if (Test-Path $p) {
        Set-ItemProperty -Path $p -Name Start -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        W ('registry Start=4: ' + $svc)
    }
}

W '=== SECURITY HEALTH TRAY / APP ==='
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'SecurityHealth' -ErrorAction SilentlyContinue
W 'SecurityHealth startup removed'
Get-AppxPackage -Name 'Microsoft.SecHealthUI' -AllUsers -ErrorAction SilentlyContinue |
    ForEach-Object {
        try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; W ('removed appx: ' + $_.PackageFullName) }
        catch { W ('SecHealthUI remove failed: ' + $_.Exception.Message) }
    }
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object { $_.PackageName -eq 'Microsoft.SecHealthUI' } |
    ForEach-Object {
        try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop; W 'SecHealthUI unprovisioned' }
        catch { W ('SecHealthUI unprovision failed: ' + $_.Exception.Message) }
    }

W '=== VERIFY ==='
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, BehaviorMonitorEnabled,
        IoavProtectionEnabled, AntispywareEnabled, IsTamperProtected |
    Format-List | Out-String | Write-Output
Get-Service WinDefend, wscsvc, SecurityHealthService -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-Process MsMpEng, SecurityHealthService, SecurityHealthSystray, SecHealthUI -ErrorAction SilentlyContinue |
    Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' -ErrorAction SilentlyContinue |
    Format-List | Out-String | Write-Output
