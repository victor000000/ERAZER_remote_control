# Compatibility shim; requires the complete repository or maintained bundle.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\scripts\system\Get-AutostartStatus.ps1') @args
