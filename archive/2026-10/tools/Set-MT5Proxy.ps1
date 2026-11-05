$ErrorActionPreference = 'Stop'
$ini = 'C:\MetaTrader 5 IC Markets Global\Config\common.ini'
Copy-Item -LiteralPath $ini -Destination "$ini.bak-proxy" -Force
$c = [IO.File]::ReadAllText($ini)
$c = [regex]::Replace($c, '(?m)^ProxyEnable=.*$', 'ProxyEnable=1')
$c = [regex]::Replace($c, '(?m)^ProxyType=.*$', 'ProxyType=2')
$c = [regex]::Replace($c, '(?m)^ProxyAddress=.*$', 'ProxyAddress=192.168.137.1:7897')
$c = [regex]::Replace($c, '(?m)^ProxyAuth=.*$', 'ProxyAuth=')
[IO.File]::WriteAllText($ini, $c, [Text.Encoding]::Default)
Get-Content -LiteralPath $ini | Select-String 'Proxy'
