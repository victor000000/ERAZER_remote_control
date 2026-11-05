$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- HONOR UNINSTALL ENTRIES (by publisher) ---'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue |
    Where-Object { $_.Publisher -match 'Honor|HONOR|QiAnXin|qianxin|A-Volute|Ubisoft' } |
    ForEach-Object {
        W ('KEY=' + $_.PSChildName)
        W ('  DisplayName=[' + $_.DisplayName + '] Publisher=[' + $_.Publisher + '] Version=' + $_.DisplayVersion)
        W ('  InstallLocation=[' + $_.InstallLocation + ']')
        W ('  UninstallString=[' + $_.UninstallString + ']')
        W ('  QuietUninstallString=[' + $_.QuietUninstallString + ']')
    }

W '--- PCManager folder listing ---'
Get-ChildItem 'C:\Program Files\HONOR\PCManager' -ErrorAction SilentlyContinue |
    Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String -Width 160 | Write-Output
Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Filter '*uninst*' -Recurse -ErrorAction SilentlyContinue |
    Select-Object FullName | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- BasicService folder ---'
Get-ChildItem 'C:\Program Files\HONOR\BasicService' -ErrorAction SilentlyContinue |
    Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output

W '--- QiAnXin folder ---'
Get-ChildItem 'C:\Program Files (x86)\qianxin' -ErrorAction SilentlyContinue |
    Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output
Get-ChildItem 'C:\Program Files (x86)\qianxin' -Filter '*uninst*' -Recurse -ErrorAction SilentlyContinue |
    Select-Object FullName | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- HONOR scheduled tasks / services detail ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|Honor|qianxin' } |
    Select-Object Name, State, StartMode, StartName, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 240 | Write-Output

W '--- UBISOFT UAC / service ---'
Get-CimInstance Win32_Service -Name UpcElevationService -ErrorAction SilentlyContinue |
    Format-List Name, State, StartMode, PathName | Out-String | Write-Output
