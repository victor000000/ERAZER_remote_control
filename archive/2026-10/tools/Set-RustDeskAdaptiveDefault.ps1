$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$f = 'C:\Users\victo\AppData\Roaming\RustDesk\config\RustDesk2.toml'
if (-not (Test-Path $f)) { Write-Output 'RustDesk2.toml missing'; exit 1 }
$c = Get-Content $f -Raw
if ($c -notmatch '(?m)^view-style\s*=') {
    $c = $c -replace '(?m)^\[options\]\r?\n', "[options]`r`nview-style = 'adaptive'`r`n"
    Set-Content -Path $f -Value $c -Encoding UTF8
    Write-Output 'added view-style = adaptive'
} else {
    $c = $c -replace '(?m)^view-style\s*=.*$', "view-style = 'adaptive'"
    Set-Content -Path $f -Value $c -Encoding UTF8
    Write-Output 'view-style already present; normalized to adaptive'
}
Write-Output '--- [options] ---'
$inOptions = $false
Get-Content $f | ForEach-Object {
    if ($_ -match '^\[options\]') { $inOptions = $true }
    elseif ($_ -match '^\[') { $inOptions = $false }
    if ($inOptions) { Write-Output $_ }
}
