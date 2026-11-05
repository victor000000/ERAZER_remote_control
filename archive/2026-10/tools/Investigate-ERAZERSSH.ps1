$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('SSH investigation: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '=== VERSION / CAPABILITY ==='
Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue |
    Select-Object Name, State | Format-Table -AutoSize | Out-String | Write-Output
(Get-Item 'C:\Windows\System32\OpenSSH\sshd.exe' -ErrorAction SilentlyContinue).VersionInfo |
    Select-Object FileVersion, ProductVersion | Format-List | Out-String | Write-Output
(& 'C:\Windows\System32\OpenSSH\ssh.exe' -V 2>&1) | ForEach-Object { W $_ }

W '=== SERVICE / RECOVERY ==='
Get-Service sshd -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
sc.exe qfailure sshd 2>&1 | ForEach-Object { W $_ }

W '=== ACTIVE CONFIG ==='
Get-Content 'C:\ProgramData\ssh\sshd_config' -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { W $_ }

W '=== 7031 / APPLICATION ERRORS ==='
$since = (Get-Date).AddDays(-3)
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; Id=7031; StartTime=$since} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List | Out-String | Write-Output
Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -match 'Application Error|Windows Error Reporting|sshd' } |
    Select-Object -First 12 TimeCreated, ProviderName, Id, Message |
    Format-List | Out-String -Width 220 | Write-Output

W '=== OPENSSH LOGS ==='
Get-ChildItem 'C:\ProgramData\ssh\logs' -ErrorAction SilentlyContinue |
    Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String | Write-Output
$sshdLog = 'C:\ProgramData\ssh\logs\sshd.log'
if (Test-Path $sshdLog) {
    Get-Content $sshdLog -Tail 100 -ErrorAction SilentlyContinue | ForEach-Object { W $_ }
}
Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 30 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-List | Out-String -Width 220 | Write-Output

W '=== WLAN / UPDATE TIMELINE ==='
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WLAN-AutoConfig/Operational'; StartTime=$since; Level=1,2} -ErrorAction SilentlyContinue |
    Select-Object -First 12 TimeCreated, Id, LevelDisplayName, Message |
    Format-List | Out-String -Width 220 | Write-Output
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; StartTime=$since} -ErrorAction SilentlyContinue |
    Select-Object -First 10 TimeCreated, Id, Message | Format-List | Out-String -Width 220 | Write-Output
