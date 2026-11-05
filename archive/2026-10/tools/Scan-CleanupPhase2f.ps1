$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$f = 'C:\Program Files\HONOR\PCManager\UninstallGuide.exe'
$bytes = [System.IO.File]::ReadAllBytes($f)
$txt = [System.Text.Encoding]::ASCII.GetString($bytes)
$seen = @{}
$idx = 0
while (($idx = $txt.IndexOf('.exe', $idx)) -ge 0) {
    $s = [Math]::Max(0, $idx - 90)
    $l = [Math]::Min(130, $txt.Length - $s)
    $snip = ($txt.Substring($s, $l) -replace '[^\x20-\x7E]', '.')
    $key = $snip.Substring(0, [Math]::Min(60, $snip.Length))
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        W ('...' + $snip + '...')
    }
    $idx += 4
}
W '--- uninstall-related strings in PCManager tree ---'
Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Recurse -Include '*.json','*.xml','*.ini','*.cfg' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'uninstall|Uninstall' -List -ErrorAction SilentlyContinue |
    Select-Object -First 20 Path | ForEach-Object { W $_.Path }
