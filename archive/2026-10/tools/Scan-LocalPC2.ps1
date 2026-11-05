$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
W ('user=' + $id.Name + ' elevated=' + $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

W '--- RECALL FEATURE (DISM) ---'
(dism.exe /online /get-featureinfo /featurename:Recall 2>&1) | Select-Object -First 10 | ForEach-Object { W $_ }

W '--- WINDOWS AI POLICY ---'
foreach ($p in @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI',
                 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI')) {
    $k = Get-ItemProperty $p -ErrorAction SilentlyContinue
    W ($p + ' => ' + (($k | Out-String).Trim()))
}

W '--- RECALL / AI APPX ---'
$apps = Get-AppxPackage -ErrorAction SilentlyContinue
W ('Appx count=' + @($apps).Count)
$apps | Where-Object { $_.Name -match 'Recall|Copilot|ClickToDo|WindowsAI|AICloud' } |
    Select-Object Name, Version, Status | Format-Table -AutoSize | Out-String | Write-Output

W '--- OPTIONAL FEATURES MATCHING AI/RECALL ---'
(dism.exe /online /get-features /format:table 2>&1) | Select-String -Pattern 'Recall|AI' | ForEach-Object { W $_.Line }

W '--- TEMP SIZES ---'
foreach ($d in @($env:TEMP, 'C:\Windows\Temp')) {
    if (Test-Path $d) {
        $s = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        W ($d + ' = ' + [math]::Round($s/1MB,1) + ' MB')
    }
}

W '--- RECYCLE BIN ---'
try {
    $rb = @((New-Object -ComObject Shell.Application).NameSpace(10).Items())
    $sz = 0
    foreach ($i in $rb) { $sz += $i.Size }
    W ('items=' + $rb.Count + ' size=' + [math]::Round($sz/1MB,1) + ' MB')
} catch { W 'recycle read failed' }

W '--- SOFTWARE DISTRIBUTION ---'
if (Test-Path 'C:\Windows\SoftwareDistribution\Download') {
    $s = (Get-ChildItem 'C:\Windows\SoftwareDistribution\Download' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    W ('WU download cache = ' + [math]::Round($s/1MB,1) + ' MB')
}

W '--- WSL CONFIG ---'
$wslcfg = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path $wslcfg) { W ((Get-Content $wslcfg -Raw)) } else { W '.wslconfig not present (WSL uses defaults)' }
W ('vmmemWSL WS MB=' + [math]::Round((Get-Process vmmemWSL -ErrorAction SilentlyContinue).WorkingSet64/1MB))

W '--- DIAGTRACK / MAPSBROKER ---'
Get-Service DiagTrack, MapsBroker, WSearch, SysMain, Spooler -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType, CanStop | Format-Table -AutoSize | Out-String | Write-Output
