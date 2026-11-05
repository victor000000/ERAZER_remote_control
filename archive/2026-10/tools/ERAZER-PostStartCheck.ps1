$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$p = Get-Process sqcli -ErrorAction SilentlyContinue
W ('sqcli pid=' + $p.Id + ' priority=' + $p.PriorityClass + ' WS_MB=' + [math]::Round($p.WorkingSet64/1MB))
W ('RAM free MB=' + [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1KB))

$proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
W ('ProxyEnable=' + $proxy.ProxyEnable + ' ProxyServer=' + $proxy.ProxyServer)
try { W ('192.168.0.2:7897 reachable=' + (Test-NetConnection 192.168.0.2 -Port 7897 -WarningAction SilentlyContinue).TcpTestSucceeded) } catch { W 'proxy test failed' }

$db = 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\databanks\databank1_S001_use_nasdaq100'
W ('databank1 count=' + @(Get-ChildItem $db -File -Filter '*.sqx' -ErrorAction SilentlyContinue).Count + ' (task1 cap 200)')

Get-ScheduledTask -TaskName 'SQX-Task1-Headless' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
(& 'C:\Program Files\Tailscale\tailscale.exe' status 2>&1) | Select-Object -First 3 | ForEach-Object { W ('  ' + $_) }
