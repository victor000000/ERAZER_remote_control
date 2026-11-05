$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- PROCESSES ---'
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Doubao|doubao' -or $_.ExecutablePath -match 'Doubao|doubao' } |
    ForEach-Object { W ('  ' + $_.Name + ' pid=' + $_.ProcessId + ' path=' + $_.ExecutablePath + ' cmd=' + $_.CommandLine) }

W '--- UNINSTALL ENTRIES ---'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Doubao|doubao' -or $_.Publisher -match 'Chuntian|ByteDance|ByteDance' -or $_.PSChildName -match 'Doubao|doubao' } |
    ForEach-Object {
        W ('  KEY=' + $_.PSChildName)
        W ('    DisplayName=[' + $_.DisplayName + '] Publisher=[' + $_.Publisher + '] Version=' + $_.DisplayVersion)
        W ('    InstallLocation=[' + $_.InstallLocation + ']')
        W ('    UninstallString=[' + $_.UninstallString + ']')
        W ('    QuietUninstallString=[' + $_.QuietUninstallString + ']')
    }

W '--- APPX ---'
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Doubao|ByteDance|Chuntian' } |
    Select-Object Name, Version, PackageFullName, InstallLocation | Format-List | Out-String | Write-Output

W '--- SERVICES ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Doubao|doubao' -or $_.PathName -match 'Doubao|doubao|ByteDance|Chuntian' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Format-List | Out-String -Width 220 | Write-Output

W '--- SCHEDULED TASKS ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    $hit = $false
    if ($t.TaskName -match 'Doubao|doubao') { $hit = $true }
    foreach ($a in $t.Actions) { if (($a.Execute + ' ' + $a.Arguments) -match 'Doubao|doubao|ByteDance|Chuntian') { $hit = $true } }
    if ($hit) { W ('  ' + $t.TaskPath + $t.TaskName + ' state=' + $t.State) }
}

W '--- STARTUP / RUN KEYS ---'
$runKeys = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
             'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
             'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
foreach ($k in $runKeys) {
    (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Doubao|doubao' -or $_.Value -match 'Doubao|doubao' } |
        ForEach-Object { W ('  ' + $k + ' | ' + $_.Name + ' = ' + $_.Value) }
}
foreach ($d in @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
                 (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'))) {
    if (Test-Path $d) {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Doubao|doubao' } |
            ForEach-Object { W ('  startup: ' + $_.FullName) }
    }
}

W '--- FOLDERS ---'
foreach ($p in @(
    (Join-Path $env:LOCALAPPDATA 'Doubao'),
    (Join-Path $env:LOCALAPPDATA 'doubao'),
    (Join-Path $env:APPDATA 'Doubao'),
    (Join-Path $env:APPDATA 'doubao'),
    (Join-Path $env:USERPROFILE 'Doubao'),
    'C:\Program Files\Doubao',
    'C:\Program Files (x86)\Doubao',
    'C:\ProgramData\Doubao'
)) {
    if (Test-Path $p) {
        $s = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        W ('  ' + $p + ' MB=' + [math]::Round($s/1MB,1))
    }
}
