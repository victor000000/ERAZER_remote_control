param(
    [string]$Ip = '192.168.0.5',
    [string]$Name = 'ERAZER-6JMHAKCD'
)
$hosts = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
$content = @(
    '# Copyright (c) 1993-2009 Microsoft Corp.',
    '# localhost name resolution is handled within DNS itself.',
    '# 127.0.0.1 localhost',
    '# ::1 localhost',
    "$Ip $Name"
) -join "`r`n"
$content += "`r`n"
[IO.File]::WriteAllText($hosts, $content, (New-Object System.Text.ASCIIEncoding))
$check = Get-Content -LiteralPath $hosts -Raw
$check | Out-File -LiteralPath (Join-Path $env:TEMP 'hosts-verify.txt') -Encoding utf8
