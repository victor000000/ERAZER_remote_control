[CmdletBinding(SupportsShouldProcess)]
param([string]$Project, [string]$ConfigPath, [string]$LocalConfigPath, [switch]$StopEngine, [ValidateRange(1, 600)][int]$ExitTimeoutSec = 60)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
if ($StopEngine -and -not $WhatIfPreference -and
    ($env:COMPUTERNAME -ine $config.Target.HostName -or -not ([Uri]$config.Sqx.ApiBase).IsLoopback)) {
    throw 'Engine exit verification requires local execution on the configured target with a loopback API.'
}
if ($PSCmdlet.ShouldProcess($Project, 'Stop project gracefully and save its databanks')) {
    $response = Invoke-SqxRequest -Command (New-SqxProjectCommand stop $Project) -ApiBase $config.Sqx.ApiBase -TimeoutSec 120
    if ($response -notmatch 'Project execution stopped') { throw 'SQX did not confirm project stop; engine was left alone.' }
    $response
    if ($StopEngine) {
        try { Invoke-SqxRequest -Command '-exit' -ApiBase $config.Sqx.ApiBase -TimeoutSec 15 | Out-Null }
        catch { Write-Verbose 'Exit request ended without a response; waiting for the local engine to exit.' }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (Get-Process sqcli -ErrorAction SilentlyContinue) {
            if ($clock.Elapsed.TotalSeconds -ge $ExitTimeoutSec) { throw 'Engine did not exit gracefully. No force-stop was performed.' }
            Start-Sleep -Milliseconds 500
        }
    }
}
