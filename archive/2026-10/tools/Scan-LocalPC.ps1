$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('=== LOCAL PC INVENTORY ' + $env:COMPUTERNAME + ' ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' ===')
W '--- OS / RAM / DISK ---'
$os = Get-CimInstance Win32_OperatingSystem
W ('OS=' + $os.Caption + ' build=' + $os.BuildNumber + ' uptime=' + ((Get-Date) - $os.LastBootUpTime))
W ('RAM free=' + [math]::Round($os.FreePhysicalMemory/1KB) + 'MB / ' + [math]::Round($os.TotalVisibleMemorySize/1KB) + 'MB')
Get-PSDrive C | ForEach-Object { W ('C: used=' + [math]::Round($_.Used/1GB,1) + 'GB free=' + [math]::Round($_.Free/1GB,1) + 'GB') }
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
    Select-Object AllocatedBaseSize, PeakUsage, CurrentUsage | Format-List | Out-String | Write-Output

W '--- RECALL / WINDOWS AI ---'
foreach ($p in @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI',
                 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI')) {
    $k = Get-ItemProperty $p -ErrorAction SilentlyContinue
    W ($p + ' => ' + (($k | Out-String).Trim()))
}
Get-AppxPackage -Name '*Recall*','*AI*' -ErrorAction SilentlyContinue |
    Select-Object Name, Version, Status | Format-Table -AutoSize | Out-String | Write-Output
Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue |
    Select-Object FeatureName, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- TOP MEMORY PROCESSES ---'
Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 |
    Select-Object Name, Id, @{n='WSMB';e={[math]::Round($_.WorkingSet64/1MB)}} |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- NON-MICROSOFT AUTO SERVICES ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.StartMode -eq 'Auto' -and $_.PathName -notmatch 'C:\\Windows\\' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Sort-Object Name |
    Format-Table -AutoSize -Wrap | Out-String -Width 240 | Write-Output

W '--- SELECTED SERVICES ---'
Get-Service WSearch,SysMain,DiagTrack,Fax,RemoteRegistry,Spooler,WerSvc,MapsBroker,PhoneSvc,SSDPSRV,upnphost,XblAuthManager,XblGameSave,XboxGipSvc,XboxNetApiSvc,GameInputSvc -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

W '--- STARTUP ---'
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Select-Object Name, Command, Location, User | Format-Table -AutoSize -Wrap | Out-String -Width 240 | Write-Output
foreach ($p in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')) {
    $it = Get-ItemProperty $p -ErrorAction SilentlyContinue
    if ($it) {
        W ('--- ' + $p + ' ---')
        $it.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } |
            ForEach-Object { W ($_.Name + ' = ' + $_.Value) }
    }
}

W '--- NON-MICROSOFT SCHEDULED TASKS ---'
Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
    Select-Object TaskName, TaskPath, State | Sort-Object TaskPath, TaskName |
    Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- INSTALLED PROGRAMS (non-Microsoft) ---'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.Publisher -notmatch 'Microsoft' } |
    Select-Object DisplayName, Publisher, DisplayVersion |
    Sort-Object DisplayName -Unique | ForEach-Object { W ($_.DisplayName + ' | ' + $_.Publisher + ' | ' + $_.DisplayVersion) }

W '--- CONSUMER APPX ---'
$apps = Get-AppxPackage -ErrorAction SilentlyContinue
W ('Appx count=' + $apps.Count)
$consumer = '*Xbox*','*Bing*','*Solitaire*','*Weather*','*News*','*Maps*','*People*','*Skype*','*Teams*','*Clipchamp*','*Feedback*','*GetHelp*','*GetStart*','*Tips*','*Cortana*','*MixedReality*','*OfficeHub*','*OneDrive*','*Zune*','*Groove*','*SoundRecorder*','*Camera*','*Photos*','*StickyNotes*','*Copilot*','*Recall*','*Phone*'
$apps | Where-Object { $n=$_.Name; $consumer | Where-Object { $n -like $_ } } |
    Select-Object Name, Version, Status | Sort-Object Name | Format-Table -AutoSize | Out-String | Write-Output

W '--- TEMP SIZES ---'
foreach ($d in @($env:TEMP, 'C:\Windows\Temp', "$env:LOCALAPPDATA\Temp")) {
    if (Test-Path $d) {
        try {
            $s = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            W ($d + ' = ' + [math]::Round($s/1MB,1) + ' MB')
        } catch {}
    }
}
W '--- RECYCLE BIN ---'
try {
    $rb = (New-Object -ComObject Shell.Application).NameSpace(10).Items() | Measure-Object
    W ('recycle items=' + $rb.Count)
} catch { W 'recycle bin read failed' }
