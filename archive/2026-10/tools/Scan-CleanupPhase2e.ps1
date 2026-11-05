$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

foreach ($f in @('C:\Program Files\HONOR\PCManager\qspublic\uninstall.exe',
                 'C:\Program Files\HONOR\PCManager\UninstallGuide.exe')) {
    W ('=== ' + $f + ' ===')
    if (-not (Test-Path $f)) { W 'missing'; continue }
    (Get-Item $f).VersionInfo | Format-List FileDescription, ProductName, FileVersion, CompanyName, LegalCopyright | Out-String | Write-Output
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($kw in @('/S', 'NSIS', 'Nullsoft', 'ms-settings', 'support', 'silent', 'QAX', 'QiAnXin', 'PCManager', 'uninst')) {
        $i = $txt.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 50)
            $l = [Math]::Min(140, $txt.Length - $s)
            W ('  [' + $kw + '] ...' + (($txt.Substring($s, $l) -replace '[^\x20-\x7E]', '.')) + '...')
        } else { W ('  [' + $kw + '] not found') }
    }
}

W '--- QAX component registration ---'
Get-ChildItem 'C:\Program Files\HONOR\PCManager\qspublic' -ErrorAction SilentlyContinue |
    Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Output
