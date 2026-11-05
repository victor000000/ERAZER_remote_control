function Resolve-ToolkitFilePath {
    param([Parameter(Mandatory)][string]$Path)
    # PS5.1 can wildcard-escape a module's relative literal path; normalize first.
    $absolute = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $file = Get-Item -LiteralPath $absolute -ErrorAction Stop
    if ($file -isnot [IO.FileInfo]) { throw 'Expected a filesystem file.' }
    return $file.FullName
}

function Merge-ToolkitHashtable {
    param([hashtable]$Base, [hashtable]$Override)
    $result = @{}
    foreach ($key in $Base.Keys) {
        if ($Base[$key] -is [hashtable]) { $result[$key] = Merge-ToolkitHashtable $Base[$key] @{} }
        else { $result[$key] = $Base[$key] }
    }
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-ToolkitHashtable $result[$key] $Override[$key]
        } else { $result[$key] = $Override[$key] }
    }
    return $result
}

function Get-ToolkitConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot '../../config/defaults.psd1'),
        [string]$LocalPath
    )
    $Path = Resolve-ToolkitFilePath $Path
    $config = Import-PowerShellDataFile -LiteralPath $Path -ErrorAction Stop
    if ($LocalPath) {
        $LocalPath = Resolve-ToolkitFilePath $LocalPath
        $config = Merge-ToolkitHashtable $config (Import-PowerShellDataFile -LiteralPath $LocalPath -ErrorAction Stop)
    }
    foreach ($section in @('Target', 'Sqx', 'Proxy', 'Controller')) {
        if (-not $config.ContainsKey($section) -or $config[$section] -isnot [hashtable]) { throw "Missing configuration section: $section" }
    }
    if ($config.SchemaVersion -ne 1) { throw 'Unsupported configuration schema.' }
    foreach ($key in @('InstallDirectory', 'Project', 'ApiBase', 'TaskName', 'LogDirectory', 'GuiTaskName')) {
        if (-not $config.Sqx.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($config.Sqx[$key])) { throw "Missing Sqx.$key" }
    }
    if ($config.Proxy.FailureThreshold -lt 1 -or $config.Proxy.UnknownThreshold -lt 1) { throw 'Proxy thresholds must be positive.' }
    $null = ConvertTo-SqxApiUri -ApiBase $config.Sqx.ApiBase -Command '-h'
    $null = New-SqxProjectCommand -Action status -Project $config.Sqx.Project
    return $config
}

function ConvertTo-WindowsArgument {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    if ($Value -match '[\x00\r\n]') { throw 'Command arguments cannot contain NUL or newlines.' }
    $escaped = [regex]::Replace($Value, '(\\*)"', {
        param($match)
        ('\' * (2 * $match.Groups[1].Length + 1)) + '"'
    })
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function ConvertFrom-WindowsCommandLine {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$CommandLine)
    $command = [Environment]::ExpandEnvironmentVariables([string]$CommandLine).Trim()
    if (-not $command) { return [pscustomobject]@{ Executable = ''; Arguments = ''; Kind = 'Empty' } }
    if ($command.StartsWith('\??\')) { $command = $command.Substring(4) }
    if ($command.StartsWith('\SystemRoot\', [StringComparison]::OrdinalIgnoreCase)) {
        $command = $env:SystemRoot + $command.Substring(11)
    }
    if ($command.StartsWith('"')) {
        $match = [regex]::Match($command, '^"([^"]+)"(?:\s+(.*))?$')
        if (-not $match.Success) { return [pscustomobject]@{ Executable = ''; Arguments = ''; Kind = 'Invalid' } }
        return [pscustomobject]@{ Executable = $match.Groups[1].Value; Arguments = $match.Groups[2].Value; Kind = 'Quoted' }
    }
    $match = [regex]::Match($command, '^(.*?\.(?:exe|com|cmd|bat|ps1|vbs))(?=\s|$)\s*(.*)$', 'IgnoreCase')
    if ($match.Success) {
        $exe = $match.Groups[1].Value
        $kind = 'UnquotedPath'
        if ($exe -match '\s') { $kind = 'UnquotedAmbiguous' }
        elseif ($exe -notmatch '[\\/]') { $kind = 'BareCommand' }
        return [pscustomobject]@{ Executable = $exe; Arguments = $match.Groups[2].Value; Kind = $kind }
    }
    $parts = $command -split '\s+', 2
    $arguments = ''
    if ($parts.Count -gt 1) { $arguments = $parts[1] }
    return [pscustomobject]@{ Executable = $parts[0]; Arguments = $arguments; Kind = 'BareCommand' }
}

function Get-TaskQueryFailureState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Exception]$Exception)
    for ($current = $Exception; $null -ne $current; $current = $current.InnerException) {
        if ($current -is [UnauthorizedAccessException] -or $current.HResult -eq -2147024891) { return 'AccessDenied' }
        if ($current -is [IO.FileNotFoundException] -or $current.HResult -eq -2147024894) { return 'Missing' }
    }
    return 'QueryFailed'
}

function Get-ToolkitTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    try {
        $scheduler = New-Object -ComObject Schedule.Service -ErrorAction Stop
        $scheduler.Connect()
        $task = $scheduler.GetFolder('\').GetTask($Name)
        $states = @('Unknown', 'Disabled', 'Queued', 'Ready', 'Running')
        return [pscustomobject]@{
            Name = $Name; QueryState = 'Present'; RunState = $states[[int]$task.State]
            Enabled = [bool]$task.Enabled; LastResult = $task.LastTaskResult; LastRun = $task.LastRunTime
        }
    } catch {
        return [pscustomobject]@{
            Name = $Name; QueryState = (Get-TaskQueryFailureState $_.Exception); RunState = 'Unknown'
            Enabled = $null; LastResult = $null; LastRun = $null
        }
    }
}

function New-SqxTaskAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EngineScript,
        [Parameter(Mandatory)][string]$Project,
        [ValidateRange(1,999)][int]$Task = 1,
        [string]$ConfigPath,
        [string]$LocalConfigPath
    )
    $null = New-SqxProjectCommand startFromTask $Project $Task
    $tokens = @('-Task', [string]$Task, '-Project', $Project)
    if ($ConfigPath) { $tokens += @('-ConfigPath', (Resolve-ToolkitFilePath $ConfigPath)) }
    if ($LocalConfigPath) { $tokens += @('-LocalConfigPath', (Resolve-ToolkitFilePath $LocalConfigPath)) }
    $scriptPath = Resolve-ToolkitFilePath $EngineScript
    return New-HeadlessTaskAction -ScriptPath $scriptPath -Arguments $tokens
}

function New-HeadlessTaskAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [string]$PowerShellPath = 'C:\Program Files\PowerShell\7\pwsh.exe',
        [string[]]$Arguments = @()
    )
    $tokens = @($PowerShellPath, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
    $encoded = @($tokens | ForEach-Object { ConvertTo-WindowsArgument $_ })
    $windows = $env:SystemRoot
    if (-not $windows) { $windows = 'C:\Windows' }
    return [pscustomobject]@{ Execute = (Join-Path $windows 'System32/conhost.exe'); Arguments = '--headless ' + ($encoded -join ' ') }
}
