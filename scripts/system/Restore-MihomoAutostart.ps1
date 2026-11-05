[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param([string]$ConfigPath, [string]$LocalConfigPath)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
$before = @($config.Controller.ExpectedTasks | ForEach-Object { Get-ToolkitTask -Name $_ })
if ($before.QueryState -contains 'AccessDenied' -or $before.QueryState -contains 'QueryFailed') { throw 'Task inspection is incomplete. Run elevated; inaccessible tasks must never be treated as missing.' }
$repair = @($before | Where-Object { $_.QueryState -eq 'Missing' -or ($_.QueryState -eq 'Present' -and -not $_.Enabled) })
if (-not $repair.Count) { $before; return }
$registrar = $config.Controller.MihomoRegistrar
if (-not (Test-Path -LiteralPath $registrar -PathType Leaf)) { throw 'External mihomo registrar was not found; nothing was changed.' }
if ($PSCmdlet.ShouldProcess($registrar, 'Run the external proxy-stack registrar and verify expected tasks')) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Elevated permissions are required to restore SYSTEM tasks.' }
    $global:LASTEXITCODE = 0
    & $registrar | Write-Verbose
    if (-not $? -or $LASTEXITCODE -ne 0) { throw 'Proxy-stack registration failed.' }
    $after = @($config.Controller.ExpectedTasks | ForEach-Object { Get-ToolkitTask -Name $_ })
    if (@($after | Where-Object { $_.QueryState -ne 'Present' -or -not $_.Enabled }).Count) { throw 'Expected tasks were not all restored and enabled.' }
    $after
}
