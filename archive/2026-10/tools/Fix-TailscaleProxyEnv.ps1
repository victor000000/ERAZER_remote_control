$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', $null, 'Machine')
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $null, 'Machine')
Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tailscale' -Name Environment -ErrorAction SilentlyContinue
Restart-Service Tailscale -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 10

Write-Output '=== TAILSCALE STATUS ==='
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
(& $ts status 2>&1) | Select-Object -First 8 | ForEach-Object { Write-Output $_ }

Write-Output '=== SERVICES ==='
Get-Service WinRM, sshd, Tailscale, RustDesk -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== PROXY WATCHER PROCESS ==='
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'Sync-ProxyWithNetwork' } |
    Select-Object ProcessId, Name | Format-Table -AutoSize | Out-String | Write-Output
Get-ScheduledTask -TaskName 'SyncProxyWithNetwork' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== PROXY SETTINGS ==='
$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
Write-Output ('WinINET Enable=' + $p.ProxyEnable + ' Server=' + $p.ProxyServer)
(netsh winhttp show proxy 2>&1) | ForEach-Object { Write-Output $_ }

Write-Output '=== PROXY WATCHER LOG TAIL ==='
$log = 'C:\Users\Vic\ERAZER-Tools\Proxy\proxy-watch.log'
if (Test-Path $log) { Get-Content $log -Tail 12 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_ } }
