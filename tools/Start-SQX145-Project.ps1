# Compatibility shim; invoke the engine only through its registered scheduled task.
$ErrorActionPreference = 'Stop'
$LASTEXITCODE = 0
& (Join-Path $PSScriptRoot '..\scripts\sqx\Start-SqxEngine.ps1') -Task 2 @args
exit $LASTEXITCODE
