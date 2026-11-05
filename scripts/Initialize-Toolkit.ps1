param([string]$ConfigPath, [string]$LocalConfigPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1') -Global -ErrorAction Stop
$parameters = @{}
if ($ConfigPath) { $parameters.Path = $ConfigPath }
if ($LocalConfigPath) { $parameters.LocalPath = $LocalConfigPath }
Get-ToolkitConfig @parameters
