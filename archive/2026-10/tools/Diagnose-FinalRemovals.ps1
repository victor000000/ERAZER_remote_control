$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- DRIVERS/SERVICES REFERENCING PCManager / OS2SOC ---'
Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'OS2SOC|PCManager|HONOR|Honor' } |
    Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Output
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'OS2SOC|PCManager|HONOR|Honor' } |
    Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Output

W '--- PCManager folder remaining ---'
if (Test-Path 'C:\Program Files\HONOR\PCManager') {
    $s = (Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    W ('size MB=' + [math]::Round($s/1MB,1))
    Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Filter '*.sys' -Recurse -Force -ErrorAction SilentlyContinue |
        Select-Object FullName, Length | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
    Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Force -ErrorAction SilentlyContinue |
        Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output
} else { W 'folder gone' }

W '--- HONOR performance tasks ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'HnPerf|PerformanceCenter|HONOR' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- UBISOFT PROCESSES ---'
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Ubisoft|Uplay|Upc|Uninstall' } |
    Select-Object Name, Id, Path | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- UBISOFT UNINSTALL ENTRY ---'
Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Uplay' -ErrorAction SilentlyContinue |
    Format-List DisplayName, DisplayVersion, InstallLocation, UninstallString, QuietUninstallString | Out-String | Write-Output

W '--- UBISOFT FOLDER ---'
if (Test-Path 'C:\Program Files (x86)\Ubisoft') {
    $s = (Get-ChildItem 'C:\Program Files (x86)\Ubisoft' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    W ('size MB=' + [math]::Round($s/1MB,1))
    Get-ChildItem 'C:\Program Files (x86)\Ubisoft' -Directory -ErrorAction SilentlyContinue | Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output
} else { W 'Ubisoft folder gone' }

W '--- UNINSTALLER STRINGS ---'
$u = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\Uninstall.exe'
if (Test-Path $u) {
    $vi = (Get-Item $u).VersionInfo
    W ('desc=' + $vi.FileDescription + ' company=' + $vi.CompanyName + ' ver=' + $vi.FileVersion)
    $asc = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($u))
    foreach ($kw in @('/S', 'silent', 'NSIS', 'Nullsoft', 'Inno')) {
        $i = $asc.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 60)
            $l = [Math]::Min(140, $asc.Length - $s)
            W ('  [' + $kw + '] ...' + (($asc.Substring($s, $l) -replace '[^\x20-\x7E]', '.')) + '...')
        }
    }
}
