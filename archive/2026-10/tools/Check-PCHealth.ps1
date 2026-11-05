$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '=== PC HEALTH ==='
W '--- TOP MEMORY PROCESSES ---'
Get-Process -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet64 -Descending | Select-Object -First 15 |
    Select-Object Name, Id, @{n='WSMB';e={[math]::Round($_.WorkingSet64/1MB)}} |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- MEMORY ---'
$os = Get-CimInstance Win32_OperatingSystem
W ('RAM free=' + [math]::Round($os.FreePhysicalMemory/1KB) + 'MB / ' + [math]::Round($os.TotalVisibleMemorySize/1KB) + 'MB')
Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
    Select-Object AllocatedBaseSize, PeakUsage, CurrentUsage | Format-List | Out-String | Write-Output

W '--- ROUTES ---'
Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object ifIndex, NextHop, RouteMetric, InterfaceMetric |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- NLA / PROFILES ---'
Get-Service NlaSvc -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceAlias, NetworkCategory | Format-Table -AutoSize | Out-String | Write-Output

W '--- HOSTS ERAZER ---'
Select-String -Path 'C:\Windows\System32\drivers\etc\hosts' -Pattern 'ERAZER' -ErrorAction SilentlyContinue |
    ForEach-Object { W $_.Line }

W '--- TAILSCALE ---'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) { (& $ts status 2>&1) | Select-Object -First 5 | ForEach-Object { W $_ } }
