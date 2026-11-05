$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('processes=' + @(Get-Process -Name 'Doubao' -ErrorAction SilentlyContinue).Count)
W ('uninstall key=' + [bool](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Doubao' -ErrorAction SilentlyContinue))
W ('HKCU Doubao=' + (Test-Path 'HKCU:\Software\Doubao') + ' ByteDance=' + (Test-Path 'HKCU:\Software\ByteDance'))
W ('Local folder=' + (Test-Path 'C:\Users\victo\AppData\Local\Doubao') + ' Roaming=' + (Test-Path 'C:\Users\victo\AppData\Roaming\Doubao') + ' Home=' + (Test-Path 'C:\Users\victo\Doubao'))

W '--- shortcuts left ---'
$shell = New-Object -ComObject WScript.Shell
$found = $false
foreach ($d in @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
                 (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
                 (Join-Path $env:USERPROFILE 'Desktop'),
                 'C:\Users\Public\Desktop')) {
    if (Test-Path $d) {
        Get-ChildItem $d -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
            $target = ''
            try { $target = $shell.CreateShortcut($_.FullName).TargetPath } catch {}
            if ($target -match 'Doubao|doubao' -or $_.Name -match 'Doubao') {
                W ('  ' + $_.FullName + ' -> ' + $target)
                $found = $true
            }
        }
    }
}
if (-not $found) { W '  none' }

W '--- services/tasks/run entries ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'Doubao|doubao' } | ForEach-Object { W ('  svc ' + $_.Name) }
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    foreach ($a in $t.Actions) { if (($a.Execute + ' ' + $a.Arguments) -match 'Doubao|doubao') { W ('  task ' + $t.TaskPath + $t.TaskName) } }
}
foreach ($k in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Value -match 'Doubao|doubao' } | ForEach-Object { W ('  run ' + $_.Name) }
}

W '--- leftover folders under profile (depth 3) ---'
Get-ChildItem 'C:\Users\victo' -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'Doubao|doubao' } | Select-Object -First 10 FullName | ForEach-Object { W ('  ' + $_.FullName) }

Get-PSDrive C | ForEach-Object { W ('C: free GB=' + [math]::Round($_.Free/1GB,1)) }
