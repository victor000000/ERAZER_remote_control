#requires -Version 5.1
<#
.SYNOPSIS
Creates dated S001 export folders and rotates the current junction without deleting old runs.
.DESCRIPTION
Saved from the verified S001 revision 2 deployment on 2026-10-20.
See docs/s001-operations.md for dependencies and execution boundaries.
#>
$ProgressPreference='SilentlyContinue';$ErrorActionPreference='Stop'
$root='C:\Users\Vic\ERAZER-Tools\StrategyArchives\S001_reproduce_project'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$run=Join-Path $root ('run-'+$stamp+'-'+$PID)
New-Item -ItemType Directory -Path $run | Out-Null
$folders=Get-Content 'C:\Users\Vic\ERAZER-Tools\SQX\S001-archive-folders.json' -Raw | ConvertFrom-Json
foreach($folder in $folders){New-Item -ItemType Directory -Path (Join-Path $run $folder) -Force | Out-Null}
$current=Join-Path $root 'current'
if(Test-Path -LiteralPath $current){
 $item=Get-Item -LiteralPath $current -Force
 if(-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Archive current path is not a junction; refusing to change it'}
 Rename-Item -LiteralPath $current -NewName ('previous-link-'+$stamp+'-'+$PID)
}
New-Item -ItemType Junction -Path $current -Target $run | Out-Null
((Get-Date -Format o)+' Archive run '+$run) | Add-Content (Join-Path $root 'runs.log')
