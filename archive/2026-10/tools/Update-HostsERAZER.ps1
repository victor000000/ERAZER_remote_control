param(
    [string]$Ip = '192.168.0.5',
    [string]$Name = 'ERAZER-6JMHAKCD'
)
$hosts = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
$name = $Name
$raw = Get-Content -LiteralPath $hosts -Raw
$newLine = "$Ip $name"
if ($raw -match [regex]::Escape($name)) {
    $raw = [regex]::Replace($raw, '(?m)^\s*\S+\s+' + [regex]::Escape($name) + '\s*$', $newLine)
}
else {
    $raw = $raw.TrimEnd() + "`r`n$newLine`r`n"
}
Set-Content -LiteralPath $hosts -Value $raw -Encoding ASCII
