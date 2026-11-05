# Compatibility shim; requires the complete repository or maintained bundle.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\scripts\sqx\Rebuild-SqxProject.ps1') @args
