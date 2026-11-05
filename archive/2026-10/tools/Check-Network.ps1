$ProgressPreference = 'SilentlyContinue'

Write-Output '=== WLAN STATE ==='
netsh wlan show interfaces

Write-Output '=== WLAN ADAPTER POWER ==='
Get-NetAdapterPowerManagement -Name 'WLAN' -ErrorAction SilentlyContinue | Format-List
Get-NetAdapterAdvancedProperty -Name 'WLAN' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Power|Sleep|Roam|U-APSD|Wake' } |
    Select-Object DisplayName, DisplayValue | Format-Table -AutoSize

Write-Output '=== WLAN EVENTS (last 30 min) ==='
Get-WinEvent -LogName 'Microsoft-Windows-WLAN-AutoConfig/Operational' -MaxEvents 150 -ErrorAction SilentlyContinue |
    Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-30) } |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Select-Object -First 20 | Format-List

Write-Output '=== MWB STATE ==='
Get-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize
Get-Process MouseWithoutBorders* -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime | Format-Table -AutoSize
netstat -ano | Select-String '15101'

Write-Output '=== SSHD VERSION ==='
(Get-Item 'C:\Windows\System32\OpenSSH\sshd.exe' -ErrorAction SilentlyContinue).VersionInfo |
    Select-Object FileVersion, ProductVersion | Format-List
