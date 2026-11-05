# Sets Windows Terminal's default profile to PowerShell 7.
# Works with the Store-packaged Windows Terminal on both machines.
param(
    [string]$Settings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
)

$oldGuid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'   # Windows PowerShell 5.1
$newGuid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # PowerShell 7 (dynamic profile)

if (-not (Test-Path -LiteralPath $Settings)) {
    Write-Output "settings.json not found: $Settings"
    exit 1
}

$raw = Get-Content -LiteralPath $Settings -Raw
if ($raw -notmatch [regex]::Escape($newGuid)) {
    Write-Output 'PowerShell 7 profile GUID not present in settings.json; aborting.'
    exit 2
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $Settings -Destination "$Settings.$stamp.bak" -Force

$raw = $raw.Replace('"defaultProfile": "' + $oldGuid + '"', '"defaultProfile": "' + $newGuid + '"')
[IO.File]::WriteAllText($Settings, $raw, (New-Object Text.UTF8Encoding($false)))

Select-String -LiteralPath $Settings -Pattern 'defaultProfile' |
    ForEach-Object { '  ' + $_.Line.Trim() }
