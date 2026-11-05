# Adds the ERAZER hostname mapping to this PC's hosts file.
# Run elevated (hidden).
param(
    [string]$Ip = '192.168.0.5',
    [string]$Name = 'ERAZER-6JMHAKCD'
)
$hosts = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
$entry = "$Ip $Name"
$content = Get-Content -LiteralPath $hosts -Raw -ErrorAction SilentlyContinue
if ($content -notmatch [regex]::Escape($Name)) {
    Add-Content -LiteralPath $hosts -Value $entry -Encoding ASCII
    'added mapping'
}
else {
    'mapping already present'
}
Get-Content -LiteralPath $hosts | Select-String -Pattern 'ERAZER|STUPIC'
