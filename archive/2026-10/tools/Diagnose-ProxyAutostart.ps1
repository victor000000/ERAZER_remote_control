$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- MIHOMO PARENT CHAIN ---'
$m = Get-CimInstance Win32_Process -Filter "Name='mihomo.exe'" -ErrorAction SilentlyContinue
foreach ($p in $m) {
    W ('  mihomo pid=' + $p.ProcessId + ' ppid=' + $p.ParentProcessId + ' cmd=' + $p.CommandLine)
    $par = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $p.ParentProcessId) -ErrorAction SilentlyContinue
    if ($par) {
        W ('    parent: ' + $par.Name + ' pid=' + $par.ProcessId + ' cmd=' + $par.CommandLine)
        $gp = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $par.ParentProcessId) -ErrorAction SilentlyContinue
        if ($gp) { W ('      grandparent: ' + $gp.Name + ' pid=' + $gp.ProcessId + ' cmd=' + $gp.CommandLine) }
    }
}
W '--- HYPOMUX PROCESSES ---'
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'hypomux' } |
    ForEach-Object { W ('  ' + $_.Name + ' pid=' + $_.ProcessId + ' ppid=' + $_.ParentProcessId + ' cmd=' + $_.CommandLine) }

W '--- HYPoMUX SERVICE CONFIG ---'
Get-CimInstance Win32_Service -Filter "Name='HypoMuxCore'" -ErrorAction SilentlyContinue |
    Format-List Name, State, StartMode, PathName | Out-String | Write-Output
$cfg = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\HypoMuxCore' -ErrorAction SilentlyContinue
W ('  ImagePath=' + $cfg.ImagePath)

W '--- HYPoMUX CONFIG / MIHOMO REFS ---'
Get-ChildItem 'C:\ProgramData\HypoMux' -Recurse -Include '*.json','*.yaml','*.yml','*.toml','*.ini' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'mihomo' -List -ErrorAction SilentlyContinue | Select-Object -First 10 Path |
    ForEach-Object { W ('  ' + $_.Path) }

W '--- SCHEDULED TASK SCRIPT PATHS ---'
$paths = @(
    'C:\Users\victo\mihomo\src\proxy\Update-AutoLearnRules.ps1',
    'C:\Users\victo\mihomo\src\monitor\BootAudit.ps1',
    'C:\Users\victo\mihomo\src\monitor\Watch-Boot.ps1',
    'C:\Users\victo\mihomo\src\hotspot\Hotspot.ps1',
    'C:\Users\victo\mihomo\src\monitor\StatusWindow.ps1'
)
foreach ($p in $paths) { W ('  ' + $p + ' exists=' + (Test-Path $p)) }

W '--- CLAUDE RUN ENTRY TARGET ---'
$claudeRun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).Claude
W ('  Run=' + $claudeRun)
if ($claudeRun -match '"([^"]+)"') { W ('  target exists=' + (Test-Path $Matches[1])) }
W ('  current appx=' + (Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue).InstallLocation)

W '--- ALL ROOT TASKS WITH STARTUP/LOGON TRIGGERS ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -eq '\' } | ForEach-Object {
    $trigs = ($_.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','
    W ('  ' + $_.TaskName.PadRight(38) + ' ' + $_.State.ToString().PadRight(9) + ' ' + $trigs)
}
