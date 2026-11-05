[CmdletBinding(SupportsShouldProcess)]
param([ValidateRange(1, 999)][int]$Task = 1, [string]$Project, [string]$ConfigPath, [string]$LocalConfigPath)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
try {
    if (-not $WhatIfPreference -and $env:COMPUTERNAME -ine $config.Target.HostName) { throw 'Engine payload must run on the configured target machine.' }
    $code = Invoke-SqxEngine -InstallDirectory $config.Sqx.InstallDirectory -Project $Project -Task $Task -LogDirectory $config.Sqx.LogDirectory -WhatIf:$WhatIfPreference
    if ($null -ne $code) { exit $code }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
