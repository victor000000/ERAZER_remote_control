$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$files = @('C:\Program Files\HONOR\PCManager\UninstallGuide.exe',
           'C:\Program Files\HONOR\HnUpdateService\uninstall.exe',
           'C:\Program Files\HONOR\BasicService\UnInstallBasicService.exe')
foreach ($f in $files) {
    W ('=== ' + $f + ' ===')
    if (-not (Test-Path $f)) { W 'missing'; continue }
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $uni = [System.Text.Encoding]::Unicode.GetString($bytes)
    foreach ($kw in @('silent', 'Silent', 'SILENT', '/S', '-S', 'SilentUninstall', 'uninstall', 'Uninstall', 'command line', 'CommandLine')) {
        $i = $uni.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 60)
            $l = [Math]::Min(160, $uni.Length - $s)
            W ('  [U ' + $kw + '] ...' + (($uni.Substring($s, $l) -replace '[^\x20-\x7E]', '.')) + '...')
        }
    }
    $asc = [System.Text.Encoding]::ASCII.GetString($bytes)
    if ($asc.Contains('Nullsoft') -or $asc.Contains('Inno Setup')) { W '  installer kind: NSIS/Inno detected' }
}
