$ErrorActionPreference = 'Continue'
$hosts = 'C:\Windows\System32\drivers\etc\hosts'
$backup = 'C:\Users\victo\ERAZER_remote_control\hosts.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $hosts $backup -Force
$c = Get-Content $hosts -Raw
$c = $c -replace '192\.168\.137\.37\s+ERAZER-6JMHAKCD', '192.168.0.5 ERAZER-6JMHAKCD'
Set-Content -Path $hosts -Value $c -Encoding ASCII
ipconfig /flushdns | Out-Null
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
((Get-Date -Format 'HH:mm:ss') + ' hosts: ERAZER-6JMHAKCD -> 192.168.0.5 (backup ' + $backup + ')') | Out-File $log -Append -Encoding utf8
Get-Content $hosts | Where-Object { $_ -match 'ERAZER' }
