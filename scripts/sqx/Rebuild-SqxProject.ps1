<#
.SYNOPSIS
Rebuilds an SQX project with migrated template and output paths.
.DESCRIPTION
CompareProject is an expected already-transformed archive. All entry names and
uncompressed bytes must match it before publication. Existing output requires
-Force and receives a unique sibling backup. The source is never edited in place.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$SourceProject,
    [Parameter(Mandatory)][string]$OutputProject,
    [string]$OldBase = 'C:\Users\victo\Documents\quantatative_analysis',
    [string]$TemplateDir = 'C:\StrategyQuantX145\user\settings\StrategyTemplates',
    [string]$OutputDir = 'C:\StrategyQuantX145\user\S001_sys_parameters',
    [string]$CompareProject,
    [string]$TaskFile,
    [string]$TemplateFile,
    [string]$OldInstallBase,
    [string]$NewInstallBase,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if ([bool]$OldInstallBase -ne [bool]$NewInstallBase) {
    throw 'OldInstallBase and NewInstallBase must be supplied together.'
}
$replacements = @{
    (Join-Path $OldBase 'AItemplate_Breakout_SP500_template.sqx') = Join-Path $TemplateDir 'AItemplate_Breakout_SP500_template.sqx'
    (Join-Path $OldBase 'S001_random_group_template_20260925.sqx') = Join-Path $TemplateDir 'S001_random_group_template_20260925.sqx'
    (Join-Path $OldBase 'S001_entry_revised_template.sqx') = Join-Path $TemplateDir 'S001_entry_revised_template.sqx'
    (Join-Path $OldBase 'S001_sys_parameters') = $OutputDir
}
if ($OldInstallBase) { $replacements[$OldInstallBase] = $NewInstallBase }

$modulePath = Join-Path $PSScriptRoot '../../src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
Import-Module -Name $modulePath -ErrorAction Stop
$arguments = @{
    SourceProject = $SourceProject
    OutputProject = $OutputProject
    Replacements = $replacements
    Force = $Force
}
foreach ($name in @('CompareProject', 'TaskFile', 'TemplateFile', 'WhatIf', 'Confirm')) {
    if ($PSBoundParameters.ContainsKey($name)) { $arguments[$name] = $PSBoundParameters[$name] }
}
New-SqxProjectArchive @arguments
