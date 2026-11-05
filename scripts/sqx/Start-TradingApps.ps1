[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('SQX145','SQX144','Taobao')][string]$Sqx = 'SQX145', [switch]$StartMT5, [string]$ConfigPath, [string]$LocalConfigPath)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (Get-Process sqcli -ErrorAction SilentlyContinue) { throw 'SQX headless engine is running; GUI was not started.' }
$directory = $config.Sqx.InstallDirectory
if ($Sqx -eq 'SQX144') { $directory = 'C:\StrategyQuantX144' }
if ($Sqx -eq 'Taobao') { $directory = 'C:\strategyquant144taobao' }
$apps = @(@{ Process='StrategyQuantX'; Path=(Join-Path $directory 'StrategyQuantX.exe'); Arguments='' })
if ($StartMT5) { $apps += @{ Process='terminal64'; Path=(Join-Path $config.Proxy.Mt5Directory 'terminal64.exe'); Arguments='/portable' } }
foreach ($app in $apps) {
    if (Get-Process -Name $app.Process -ErrorAction SilentlyContinue) { Write-Verbose "$($app.Process) is already running."; continue }
    if (-not (Test-Path -LiteralPath $app.Path -PathType Leaf)) { throw "Application missing: $($app.Process)" }
    if ($PSCmdlet.ShouldProcess($app.Process, 'Start GUI application')) {
        if ($env:COMPUTERNAME -ine $config.Target.HostName) { throw 'Start trading applications on the configured target machine.' }
        $parameters = @{ FilePath=$app.Path; WorkingDirectory=(Split-Path -LiteralPath $app.Path); ErrorAction='Stop' }
        if ($app.Arguments) { $parameters.ArgumentList = $app.Arguments }
        Start-Process @parameters
    }
}
