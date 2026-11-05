[CmdletBinding(SupportsShouldProcess)]
param([ValidateRange(1, 999)][int]$Task = 1, [string]$Project, [string]$ConfigPath, [string]$LocalConfigPath, [ValidateRange(1, 600)][int]$ReadyTimeoutSec = 120)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
$null = New-SqxProjectCommand startFromTask $Project $Task
if (Get-Process StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue) { throw 'SQX GUI is open. Save and close it before requesting headless execution; no process was killed.' }
if (Get-Process sqcli -ErrorAction SilentlyContinue) { throw 'SQX engine is already running. Use Control-Sqx to inspect or stop it explicitly.' }
if (-not $PSCmdlet.ShouldProcess($Project, "Start existing reviewed SQX task from project task $Task")) { return }
if ($env:COMPUTERNAME -ine $config.Target.HostName) { throw 'Start SQX on the configured target machine, not the controller.' }
$current = Get-ToolkitTask -Name $config.Sqx.TaskName
if ($current.QueryState -ne 'Present') { throw "Task is $($current.QueryState). Register it explicitly with Register-SqxTask.ps1; nothing was changed." }
if (-not $current.Enabled -or $current.RunState -in @('Running', 'Queued')) { throw 'Scheduled task is disabled or active; no start was requested.' }
$expected = New-SqxTaskAction -EngineScript (Join-Path $PSScriptRoot 'Start-SqxEngine.ps1') -Task $Task -Project $Project -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
$definition = Get-ScheduledTask -TaskName $config.Sqx.TaskName -ErrorAction Stop
$actions = @($definition.Actions)
if ($actions.Count -ne 1 -or $actions[0].Execute -ine $expected.Execute -or $actions[0].Arguments -cne $expected.Arguments -or
    $actions[0].WorkingDirectory -ine $config.Sqx.InstallDirectory) { throw 'Registered task does not match the requested project/configuration/task. Review and explicitly register the desired definition.' }
Start-ScheduledTask -TaskName $config.Sqx.TaskName -ErrorAction Stop
Wait-SqxReady -Project $Project -ApiBase $config.Sqx.ApiBase -TimeoutSec $ReadyTimeoutSec
