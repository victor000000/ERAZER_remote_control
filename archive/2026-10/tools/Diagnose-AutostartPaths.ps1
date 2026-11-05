$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- APP PATHS ---'
foreach ($p in @('C:\Users\victo\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe',
                 'C:\Users\victo\AppData\Local\Programs\Docker\Docker Desktop.exe',
                 'C:\Users\victo\AppData\Local\Docker\Docker Desktop.exe',
                 'C:\Program Files\Docker\Docker\Docker Desktop.exe',
                 'C:\Program Files\Cloudflare\Cloudflare WARP\Cloudflare WARP.exe',
                 'C:\Program Files\Cloudflare\Cloudflare WARP\warp-svc.exe',
                 'C:\Users\victo\AppData\Local\Programs\CC Switch\cc-switch.exe',
                 'C:\Program Files\Microsoft OfficePLUS\4.2.0.8924\addin\MSOfficePLUSService.exe',
                 'C:\Program Files\Microsoft OfficePLUS')) {
    W ('  ' + $p + ' exists=' + (Test-Path $p))
}
W ('  Claude appx path: ' + (Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue).InstallLocation)
if (Test-Path 'C:\Users\victo\AppData\Local\Programs') {
    W '--- AppData\Local\Programs ---'
    Get-ChildItem 'C:\Users\victo\AppData\Local\Programs' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { W ('  ' + $_) }
}
W '--- Docker-ish exes ---'
Get-ChildItem 'C:\Users\victo\AppData\Local' -Filter 'Docker Desktop.exe' -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Select-Object -First 5 FullName | ForEach-Object { W ('  ' + $_.FullName) }

W '--- CLOUDFLARE FOLDER ---'
if (Test-Path 'C:\Program Files\Cloudflare\Cloudflare WARP') {
    Get-ChildItem 'C:\Program Files\Cloudflare\Cloudflare WARP' -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output
}

W '--- CC SWITCH ---'
Get-ChildItem 'C:\Users\victo\AppData\Local\Programs' -Filter '*witch*' -Directory -ErrorAction SilentlyContinue | ForEach-Object { W ('  ' + $_.FullName) }

W '--- PROXY ---'
$m = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mihomo|clash|hypomux' }
if ($m) { $m | ForEach-Object { W ('  process ' + $_.Name + ' pid=' + $_.Id + ' path=' + $_.Path) } } else { W '  no mihomo/clash process' }
$lst = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 7897 }
if ($lst) { $lst | ForEach-Object { W ('  port 7897 listening pid=' + $_.OwningProcess) } } else { W '  port 7897 NOT listening' }

W '--- MIHOMO AUTOSTART SOURCES ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'mihomo|clash' } | Select-Object Name, State, StartMode, PathName | Format-List | Out-String | Write-Output
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    foreach ($a in $t.Actions) {
        if (($a.Execute + ' ' + $a.Arguments) -match 'mihomo|clash') {
            W ('  task ' + $t.TaskPath + $t.TaskName + ' state=' + $t.State + ' exec=' + $a.Execute + ' args=' + $a.Arguments)
        }
    }
}
$runKeys = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
foreach ($k in $runKeys) {
    (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Value -match 'mihomo|clash' } |
        ForEach-Object { W ('  run ' + $k + ' ' + $_.Name + '=' + $_.Value) }
}

W '--- TAILSCALE ---'
(& 'C:\Program Files\Tailscale\tailscale.exe' status 2>&1) | Select-Object -First 4 | ForEach-Object { W ('  ' + $_) }

W '--- MWB SERVICE ---'
$svc = Get-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue
W ('  ' + $svc.Status + ' ' + $svc.StartType)
W ('  MWB process=' + @(Get-Process -Name 'MouseWithoutBorders' -ErrorAction SilentlyContinue).Count)
