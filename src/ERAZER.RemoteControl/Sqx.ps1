function New-SqxProjectCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('status', 'start', 'stop', 'pause', 'resume', 'startOnlyTask', 'startFromTask')][string]$Action,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Project,
        [ValidateRange(0, 999)][int]$Task = 0
    )
    if ($Project -match '[\x00-\x1f"=/\\]' -or $Project.Trim() -ne $Project -or $Project -in @('.', '..')) { throw 'Invalid project name.' }
    $command = '-project action=' + $Action + ' name="' + $Project + '"'
    if ($Action -in @('startOnlyTask', 'startFromTask')) {
        if ($Task -lt 1) { throw 'Task numbers are 1-based.' }
        $command += ' task=' + $Task
    }
    return $command
}

function ConvertTo-SqxApiUri {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command, [string]$ApiBase = 'http://127.0.0.1:5050')
    $base = $null
    if (-not [Uri]::TryCreate($ApiBase, [UriKind]::Absolute, [ref]$base) -or
        $base.Scheme -notin @('http', 'https') -or $base.UserInfo -or $base.Query -or $base.Fragment -or $base.AbsolutePath -ne '/') {
        throw 'ApiBase must be an HTTP(S) origin without a path, query or credentials.'
    }
    if ([string]::IsNullOrWhiteSpace($Command) -or $Command -match '[\x00\r\n]') { throw 'Invalid SQX command.' }
    # SQX rejects percent-encoded equals signs in its command grammar.
    return $base.GetLeftPart([UriPartial]::Authority) + '/call?cmd=' + [Uri]::EscapeDataString($Command).Replace('%3D', '=')
}

function Test-SqxResponse {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Content, [ValidateSet('Status', 'Help', 'Command')][string]$Kind = 'Command')
    if ([string]::IsNullOrWhiteSpace($Content) -or $Content -match '(?im)CLI not ready|^\s*Error\b|Unrecognized (?:command|action)|Unable to resolve|^\s*<(!DOCTYPE|html)') { return $false }
    if ($Kind -eq 'Status') { return ($Content -match 'Status of project ' -and $Content -match '(?m)^Strategies generated\s+\d+') }
    if ($Kind -eq 'Help') { return ($Content -match '(?m)^Usage:') }
    return $true
}

function ConvertFrom-SqxStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content)
    if (-not (Test-SqxResponse $Content -Kind Status)) { throw 'Response is not a ready SQX project status.' }
    $numbers = @{}
    foreach ($label in @('Strategies generated', 'Accepted', 'Rejected', 'Failed', 'Strategies per hour', 'Accepted strategies per hour', 'In databank')) {
        $match = [regex]::Match($Content, '(?m)^' + [regex]::Escape($label) + '\s+([\d,.]+)\s*%?\s*\r?$')
        if ($match.Success) {
            $numbers[$label] = [double]::Parse($match.Groups[1].Value.Replace(',', ''), [Globalization.CultureInfo]::InvariantCulture)
        } else { $numbers[$label] = $null }
    }
    $runtime = [regex]::Match($Content, '(?m)^Running time so far\s+(.+?)\s*\r?$').Groups[1].Value
    return [pscustomobject]@{
        Generated = $numbers['Strategies generated']; AcceptedPercent = $numbers['Accepted']
        RejectedPercent = $numbers['Rejected']; Failed = $numbers['Failed']
        GeneratedPerHour = $numbers['Strategies per hour']; AcceptedPerHour = $numbers['Accepted strategies per hour']
        ProjectDatabankCount = $numbers['In databank']; Runtime = $runtime
    }
}

function Invoke-SqxRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command, [string]$ApiBase = 'http://127.0.0.1:5050', [ValidateRange(1, 300)][int]$TimeoutSec = 20)
    $uri = ConvertTo-SqxApiUri $Command $ApiBase
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
    if (-not (Test-SqxResponse $response.Content)) { throw 'SQX returned an error or a not-ready response.' }
    return [string]$response.Content
}

function Wait-SqxReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Project,
        [string]$ApiBase = 'http://127.0.0.1:5050',
        [ValidateRange(1, 600)][int]$TimeoutSec = 120,
        [ValidateRange(1, 10000)][int]$PollIntervalMilliseconds = 500
    )
    $command = New-SqxProjectCommand status $Project
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $TimeoutSec) {
        $remaining = $TimeoutSec - $clock.Elapsed.TotalSeconds
        $requestTimeout = [math]::Max(1, [math]::Min(5, [math]::Ceiling($remaining)))
        try {
            $content = Invoke-SqxRequest -Command $command -ApiBase $ApiBase -TimeoutSec $requestTimeout
            if (Test-SqxResponse $content -Kind Status) { return ConvertFrom-SqxStatus $content }
        } catch { Write-Verbose 'SQX is not ready yet.' }
        $sleep = [math]::Min($PollIntervalMilliseconds, [math]::Max(0, 1000 * ($TimeoutSec - $clock.Elapsed.TotalSeconds)))
        if ($sleep -gt 0) { Start-Sleep -Milliseconds ([int]$sleep) }
    }
    throw [TimeoutException]::new("SQX did not become ready within $TimeoutSec seconds.")
}

function Invoke-SqxEngine {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$InstallDirectory,
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][string]$LogDirectory,
        [ValidateRange(1, 999)][int]$Task = 1
    )
    $null = New-SqxProjectCommand startFromTask $Project $Task
    $exe = Join-Path $InstallDirectory 'sqcli.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'SQX executable not found.' }
    if (-not $PSCmdlet.ShouldProcess($InstallDirectory, "Run SQX project $Project from task $Task")) { return }
    if (Get-Process sqcli, StrategyQuantX, StrategyQuantX_ui -ErrorAction SilentlyContinue) { throw 'An SQX instance already exists; refusing a duplicate launch.' }
    $null = New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $PID
    $tokens = @('-project', 'action=startFromTask', ('name=' + $Project), ('task=' + $Task))
    $arguments = ($tokens | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $InstallDirectory -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $LogDirectory "$stamp.stdout.log") -RedirectStandardError (Join-Path $LogDirectory "$stamp.stderr.log") -ErrorAction Stop
    try {
        try { $process.PriorityClass = 'High' } catch { Write-Verbose 'Unable to set SQX priority; preserving its native exit result.' }
        $process.WaitForExit()
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw 'SQX exit code could not be read.' }
        return [int]$process.ExitCode
    } finally { $process.Dispose() }
}
