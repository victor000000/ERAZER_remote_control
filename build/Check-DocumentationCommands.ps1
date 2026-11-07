#requires -Version 5.1
<#
.SYNOPSIS
Checks documented parameter names with PowerShell ASTs without executing scripts.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$document = Join-Path $root 'docs/command-reference.md'
$text = Get-Content -LiteralPath $document -Raw
$contracts = [regex]::Matches($text, '<!-- cli: ([^\r\n|]+) \| ([^\r\n]+?) -->')
if ($contracts.Count -eq 0) { throw 'No documented command contracts found.' }
foreach ($contract in $contracts) {
    $relative = $contract.Groups[1].Value.Trim()
    if ($relative -match '(^|[/\\])\.\.([/\\]|$)' -or [IO.Path]::IsPathRooted($relative)) { throw 'Command contract must reference repository source.' }
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Documented command missing: $relative" }
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Cannot parse documented command: $relative" }
    $names = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    foreach ($name in $contract.Groups[2].Value.Split(',')) {
        if ($names -notcontains $name.Trim()) { throw "Documented parameter missing from ${relative}: $($name.Trim())" }
    }
}
Write-Output ('Documentation command contracts passed: {0} scripts; no script was invoked.' -f $contracts.Count)
