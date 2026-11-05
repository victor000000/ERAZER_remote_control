$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$root = 'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces'
$target = $null
Get-ChildItem $root -Recurse -Filter '*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $x = [xml](Get-Content $_.FullName -Raw)
        if ($x.WLANProfile.name -eq 'MiFi706425-5G') { $target = $_.FullName }
    } catch { }
}
if (-not $target) { Write-Output 'MiFi profile XML not found'; exit 1 }
Write-Output ('target: ' + $target)
Copy-Item $target ($target + '.bak-auto-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
$c = Get-Content $target -Raw
$c = $c -replace '<connectionMode>manual</connectionMode>', '<connectionMode>auto</connectionMode>'
Set-Content -Path $target -Value $c -Encoding UTF8
Write-Output 'XML connectionMode changed to auto'
netsh wlan set profileparameter name="MiFi706425-5G" connectionmode=auto 2>&1 | ForEach-Object { Write-Output $_ }
$check = [xml](Get-Content $target -Raw)
Write-Output ('verify: ' + $check.WLANProfile.name + ' -> ' + $check.WLANProfile.connectionMode)
