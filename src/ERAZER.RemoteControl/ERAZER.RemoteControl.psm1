Set-StrictMode -Version Latest
foreach ($file in @('Core.ps1', 'Sqx.ps1', 'Proxy.ps1', 'ProjectArchive.ps1')) {
    . (Join-Path $PSScriptRoot $file)
}
