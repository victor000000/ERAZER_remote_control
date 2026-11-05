[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('status','start','stop','pause','resume','list','start-task','start-from-task','exit','headless','gui')][string]$Action,
    [string]$Project, [ValidateRange(0,999)][int]$Task = 0, [string]$ConfigPath, [string]$LocalConfigPath
)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
$common = @{ Project=$Project; ConfigPath=$ConfigPath; LocalConfigPath=$LocalConfigPath }
switch ($Action) {
    'status' { & (Join-Path $PSScriptRoot 'Get-SqxStatus.ps1') @common }
    'list' { Invoke-SqxRequest '-project action=list' $config.Sqx.ApiBase }
    'stop' { & (Join-Path $PSScriptRoot 'Stop-SqxProject.ps1') @common -WhatIf:$WhatIfPreference }
    'exit' { & (Join-Path $PSScriptRoot 'Stop-SqxProject.ps1') @common -StopEngine -WhatIf:$WhatIfPreference }
    'headless' {
        if ($Task -eq 0) { $Task = 1 }
        & (Join-Path $PSScriptRoot 'Start-SqxProject.ps1') @common -Task $Task -WhatIf:$WhatIfPreference
    }
    'gui' {
        if (Get-Process sqcli -ErrorAction SilentlyContinue) { throw 'Stop the engine gracefully with -Action exit before starting the GUI.' }
        if ($PSCmdlet.ShouldProcess($config.Sqx.GuiTaskName, 'Start GUI through its existing logon task')) { Start-ScheduledTask -TaskName $config.Sqx.GuiTaskName -ErrorAction Stop }
    }
    default {
        $operation = $Action
        if ($Action -eq 'start-task') { $operation = 'startOnlyTask' }
        if ($Action -eq 'start-from-task') { $operation = 'startFromTask' }
        $command = New-SqxProjectCommand -Action $operation -Project $Project -Task $Task
        if ($PSCmdlet.ShouldProcess($Project, $operation)) { Invoke-SqxRequest $command $config.Sqx.ApiBase }
    }
}
