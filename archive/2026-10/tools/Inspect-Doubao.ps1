$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$u = 'C:\Users\victo\AppData\Local\Doubao\Application\uninstall.exe'
W ('uninstaller exists=' + (Test-Path $u))
if (Test-Path $u) {
    (Get-Item $u).VersionInfo | Format-List FileDescription, ProductName, FileVersion, CompanyName | Out-String | Write-Output
    $bytes = [System.IO.File]::ReadAllBytes($u)
    $asc = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($kw in @('/S', 'silent', 'NSIS', 'Nullsoft', 'Inno Setup', 'Squirrel', 'Electron', 'uninstall')) {
        $i = $asc.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 50)
            $l = [Math]::Min(140, $asc.Length - $s)
            W ('  [' + $kw + '] ...' + (($asc.Substring($s, $l) -replace '[^\x20-\x7E]', '.')) + '...')
        }
    }
}

W '--- Doubao folder top level ---'
Get-ChildItem 'C:\Users\victo\AppData\Local\Doubao' -Force -ErrorAction SilentlyContinue |
    Select-Object Mode, Length, LastWriteTime, Name | Format-Table -AutoSize | Out-String -Width 160 | Write-Output

W '--- Application folder ---'
Get-ChildItem 'C:\Users\victo\AppData\Local\Doubao\Application' -Force -ErrorAction SilentlyContinue |
    Select-Object Mode, Length, Name | Format-Table -AutoSize | Out-String | Write-Output

W '--- shortcuts ---'
foreach ($d in @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:USERPROFILE 'Desktop'),
    'C:\Users\Public\Desktop'
)) {
    if (Test-Path $d) {
        Get-ChildItem $d -Recurse -Filter '*Doubao*' -ErrorAction SilentlyContinue | ForEach-Object { W ('  ' + $_.FullName) }
        Get-ChildItem $d -Recurse -Filter '*豆包*' -ErrorAction SilentlyContinue | ForEach-Object { W ('  ' + $_.FullName) }
    }
}

W '--- processes ---'
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Doubao|doubao' } | Select-Object Name, Id, Path | Format-Table -AutoSize | Out-String | Write-Output

W '--- related registry keys ---'
foreach ($k in @('HKCU:\Software\Doubao', 'HKCU:\Software\ByteDance', 'HKCU:\Software\Chuntian',
                 'HKLM:\Software\Doubao', 'HKLM:\Software\ByteDance')) {
    W ('  ' + $k + ' exists=' + (Test-Path $k))
}
