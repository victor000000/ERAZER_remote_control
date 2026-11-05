# Compatibility shim; requires the complete repository or maintained bundle.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\scripts\sqx\Control-Sqx.ps1') @args
