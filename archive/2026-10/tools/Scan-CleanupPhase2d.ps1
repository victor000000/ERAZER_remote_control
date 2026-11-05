$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- UNINSTALLERS UNDER C:\Program Files\HONOR ---'
Get-ChildItem 'C:\Program Files\HONOR' -Recurse -Filter '*uninst*.exe' -ErrorAction SilentlyContinue |
    Select-Object FullName, Length | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- UninstallGuide.exe VERSION INFO ---'
$f = 'C:\Program Files\HONOR\PCManager\UninstallGuide.exe'
if (Test-Path $f) {
    (Get-Item $f).VersionInfo | Format-List FileDescription, ProductName, FileVersion, CompanyName | Out-String | Write-Output
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($kw in @('silent', '/S', '-silent', 'uninstall', 'Uninstall', 'params', 'command')) {
        $i = $txt.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 40)
            $l = [Math]::Min(120, $txt.Length - $s)
            $snip = ($txt.Substring($s, $l) -replace '[^\x20-\x7E]', '.')
            W ('  [' + $kw + '] ...' + $snip + '...')
        }
    }
} else { W 'UninstallGuide.exe missing' }

W '--- HUNTERCAMP uninst ---'
$h = 'C:\Program Files\HONOR\HunterCamp\uninst.exe'
if (Test-Path $h) {
    (Get-Item $h).VersionInfo | Format-List FileDescription, ProductName, FileVersion, CompanyName | Out-String | Write-Output
} else { W 'HunterCamp uninst.exe missing' }

W '--- HONOR RUN ENTRIES / STARTUP ---'
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Where-Object { $_.Command -match 'HONOR|Honor|PCManager|Hn' } |
    Select-Object Name, Command, Location | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output

W '--- HONOR TASKS FULL ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'Honor|HONOR|PCManager|Hn' -or $_.TaskPath -match 'Honor|HONOR' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

W '--- SERVICES WITH HONOR-CONTROLLED START ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|Honor|qianxin|Hihonornote' } |
    Select-Object Name, State, StartMode | Format-Table -AutoSize | Out-String | Write-Output
