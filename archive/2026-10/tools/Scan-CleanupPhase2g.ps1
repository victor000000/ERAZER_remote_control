$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

$exes = @(
    'C:\Program Files\HONOR\BasicService\UnInstallBasicService.exe',
    'C:\Program Files\HONOR\HNPCAIService\Uninstall.exe',
    'C:\Program Files\HONOR\HNPCInferEngine\Uninstall.exe',
    'C:\Program Files\HONOR\HnUpdateService\uninstall.exe',
    'C:\Program Files\HONOR\HunterCamp\uninst.exe',
    'C:\Program Files\HONOR\HnLcdEnhancement\LCDUninstall.exe',
    'C:\Program Files\HONOR\DiagnoseAnalysis\uninstall.exe',
    'C:\Program Files\HONOR\RemoteService\uninstall.exe',
    'C:\Program Files\HONOR\PCManager\qspublic\uninstall.exe'
)
foreach ($f in $exes) {
    W ('=== ' + $f + ' ===')
    if (-not (Test-Path $f)) { W '  missing'; continue }
    try {
        $vi = (Get-Item $f).VersionInfo
        W ('  desc=' + $vi.FileDescription + ' company=' + $vi.CompanyName + ' ver=' + $vi.FileVersion)
    } catch {}
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($kw in @('-SilentUninstall', '/S', '/silent', '-silent', 'uninstallall', '-Uninstall', 'Inno Setup', 'Nullsoft')) {
        $i = $txt.IndexOf($kw)
        if ($i -ge 0) {
            $s = [Math]::Max(0, $i - 70)
            $l = [Math]::Min(150, $txt.Length - $s)
            W ('  [' + $kw + '] ...' + (($txt.Substring($s, $l) -replace '[^\x20-\x7E]', '.')) + '...')
        }
    }
}
