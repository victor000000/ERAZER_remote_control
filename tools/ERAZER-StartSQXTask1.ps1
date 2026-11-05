# Compatibility shim; requires the complete repository or maintained bundle.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\scripts\sqx\Start-SqxProject.ps1') -Task 1 @args
