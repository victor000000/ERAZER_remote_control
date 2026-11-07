[CmdletBinding(SupportsShouldProcess)]
param([ValidateRange(1, 999)][int]$Task = 1, [string]$Project, [string]$ConfigPath, [string]$LocalConfigPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
$null = New-SqxProjectCommand startFromTask $Project $Task
$current = Get-ToolkitTask -Name $config.Sqx.TaskName
if ($current.QueryState -notin @('Present', 'Missing')) { throw "Cannot inspect existing task: $($current.QueryState). Run elevated; do not assume it is missing." }
if ($current.QueryState -eq 'Present' -and $current.RunState -in @('Running', 'Queued')) { throw 'Task is active; refusing to replace its definition.' }
if ($current.QueryState -eq 'Present' -and $current.RunState -notin @('Ready', 'Disabled')) { throw 'Existing task state is not confirmed idle; refusing to replace its definition.' }
if ($current.QueryState -eq 'Present' -and -not $Force) { throw 'Task already exists. Review its definition; explicit -Force is required to replace an idle task.' }
$engineScript = Join-Path $PSScriptRoot 'Start-SqxEngine.ps1'
$actionSpec = New-SqxTaskAction -EngineScript $engineScript -Task $Task -Project $Project -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if ($PSCmdlet.ShouldProcess($config.Sqx.TaskName, 'Register manual headless SQX task (no boot/logon trigger)')) {
    if ($env:COMPUTERNAME -ine $config.Target.HostName) { throw 'Register SQX tasks on the configured target machine, not the controller.' }
    if ($config.Sqx.TaskName.Trim('\') -ieq 'SQX-Task1-Headless') { throw 'The S001 preserving task is protected. Use its dedicated preserving runbook; generic registration cannot replace or recreate it.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($identity -notmatch ('\\' + [regex]::Escape($config.Target.User) + '$')) { throw 'Register the interactive SQX task as the configured ERAZER user.' }
    if ($current.QueryState -eq 'Present') {
        $xml = Export-ScheduledTask -TaskName $config.Sqx.TaskName -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $config.Sqx.LogDirectory -Force -ErrorAction Stop
        $backup = Join-Path $config.Sqx.LogDirectory ('sqx-task-' + [Guid]::NewGuid().ToString('N') + '.xml')
        [IO.File]::WriteAllText($backup, $xml)
    }
    $action = New-ScheduledTaskAction -Execute $actionSpec.Execute -Argument $actionSpec.Arguments -WorkingDirectory $config.Sqx.InstallDirectory
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $settings.Hidden = $true
    Register-ScheduledTask -TaskName $config.Sqx.TaskName -Action $action -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
    Get-ToolkitTask -Name $config.Sqx.TaskName
}
