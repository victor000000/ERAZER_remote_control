$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$root = 'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces'
Get-ChildItem $root -Recurse -Filter '*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $x = [xml](Get-Content $_.FullName -Raw)
        $n = $x.WLANProfile.name
        $m = $x.WLANProfile.connectionMode
        Write-Output ($n + ' -> ' + $m)
    } catch { }
}
Write-Output '--- CURRENT ---'
(netsh wlan show interfaces 2>&1) | Select-String 'State|SSID|Signal' | ForEach-Object { Write-Output $_.Line.Trim() }
