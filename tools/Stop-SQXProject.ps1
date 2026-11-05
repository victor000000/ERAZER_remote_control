# Compatibility shim; requires the complete repository or maintained bundle.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\scripts\sqx\Stop-SqxProject.ps1') @args
