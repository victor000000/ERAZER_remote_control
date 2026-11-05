#requires -Version 5.1
<#
.SYNOPSIS
Applies the reviewed 32 GB ERAZER heap profile while retaining the current S001 build banks.
.DESCRIPTION
Run on ERAZER through Task Scheduler. Supports maintenance while S001 is on
its first build only. Saves and verifies a complete project backup, stops SQX
gracefully, updates sqcli.config, and reuses the prepared-run path in the
existing launcher. Never force-kills an engine or edits a project ZIP.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
 [Parameter(Mandatory)][string]$RunDirectory,
 [ValidateRange(24,29)][int]$MaximumHeapGB=29
)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$install='C:\StrategyQuantX145'
$tool='C:\Users\Vic\ERAZER-Tools\SQX'
$project=Join-Path $install 'user\projects\S001_reproduce_project'
$config=Join-Path $install 'sqcli.config'
$ledgerPath=Join-Path $tool 'S001-preservation-last-run.json'
$taskName='SQX-Task1-Headless'
$oldExited=$false;$configChanged=$false
function Write-MemoryLog([string]$Message){((Get-Date -Format o)+' '+$Message) | Add-Content -LiteralPath (Join-Path $RunDirectory 'maintenance.log')}
function Invoke-MemoryApi([string]$Command){
 $response=(Invoke-WebRequest ('http://127.0.0.1:5050/call?cmd='+$Command.Replace(' ','%20')) -UseBasicParsing -TimeoutSec 300).Content
 if($response -match '(?im)^error:'){throw $response};return $response
}
function Set-PreparedCurrentRun {
 $state=Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
 if($state.Run -ne $originalRun){throw 'Current S001 run changed; refusing to prepare another run'}
 $state.ProjectHash=(Get-FileHash -LiteralPath (Join-Path $project 'project.cfx')).Hash
 $state.BlueprintHash=$blueprintHash;$state.PreparedForLaunch=$true
 $temporary=$ledgerPath+'.memory-'+[guid]::NewGuid().ToString('N')+'.tmp'
 $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding UTF8
 [IO.File]::Replace($temporary,$ledgerPath,(Join-Path $RunDirectory ('ledger-before-prepare-'+(Get-Date -Format yyyyMMddHHmmssfff)+'.json')))
}
if($env:COMPUTERNAME -ne 'ERAZER-6JMHAKCD'){throw 'This profile is for ERAZER only'}
if(-not [IO.Path]::IsPathRooted($RunDirectory)){throw 'RunDirectory must be absolute'}
if(-not (Test-Path -LiteralPath $RunDirectory -PathType Container)){throw 'Create a dedicated run directory before scheduling this script'}
if(Test-Path (Join-Path $RunDirectory 'memory-change-started.json')){throw 'Use a fresh run directory; this maintenance run cannot be repeated'}
$ramGB=(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1MB
if($ramGB -lt 31 -or $ramGB -gt 33){throw 'Reassess the heap profile for this physical RAM capacity'}
$processes=@(Get-Process sqcli -ErrorAction SilentlyContinue)
if($processes.Count -ne 1 -or (Get-Process StrategyQuantX,StrategyQuantX_ui -ErrorAction SilentlyContinue)){throw 'Expected exactly one headless SQX engine'}
$oldPID=$processes[0].Id
$lastLog=Get-ChildItem (Join-Path $project 'log') -File -Filter 'global_log_*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$lastTask=@(Select-String -LiteralPath $lastLog.FullName -Pattern '^Task: (.+), Type:' | Select-Object -Last 1)
if($lastTask.Count -ne 1 -or $lastTask[0].Matches[0].Groups[1].Value -ne 'Build 1: S001 Nasdaq template (cap 200)'){throw 'Maintenance resume is supported only during the first S001 build'}
$prior=Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$originalRun=$prior.Run
$manifest=Get-Content (Join-Path $tool 'S001-preservation-manifest.json') -Raw | ConvertFrom-Json
$blueprintHash=(Get-FileHash (Join-Path $tool 'S001-preservation-blueprint.cfx')).Hash
if($prior.Revision -ne 2 -or $blueprintHash -ne $manifest.blueprintSha256){throw 'Unexpected preservation revision or blueprint'}
$oldLines=[IO.File]::ReadAllLines($config)
if(@($oldLines | Where-Object {$_ -match '^option\s+-Xms'}).Count -ne 1 -or @($oldLines | Where-Object {$_ -match '^option\s+-Xmx'}).Count -ne 1){throw 'Expected one initial and one maximum heap option'}
$projectBytes=(Get-ChildItem -LiteralPath $project -File -Recurse | Measure-Object Length -Sum).Sum
if((Get-PSDrive C).Free -lt ($projectBytes*1.2+1GB)){throw 'Insufficient disk space for a full verified project backup'}
if(-not $PSCmdlet.ShouldProcess('ERAZER S001', "Back up, gracefully restart with Xms20g/Xmx${MaximumHeapGB}g/GCTimeRatio99, and retain the current run banks")){return}
try {
 $metadata=[ordered]@{StartedAt=(Get-Date).ToString('o');OldPID=$oldPID;Run=$originalRun;InitialHeapGB=20;MaximumHeapGB=$MaximumHeapGB;GCTimeRatio=99;Project=$project;Backup=(Join-Path $RunDirectory 'saved-project')}
 $metadata | ConvertTo-Json | Set-Content (Join-Path $RunDirectory 'memory-change-started.json') -Encoding UTF8
 Copy-Item -LiteralPath $config -Destination (Join-Path $RunDirectory 'sqcli.config.before')
 Copy-Item -LiteralPath $ledgerPath -Destination (Join-Path $RunDirectory 'ledger.before.json')
 # A running SQX can keep working during a proxy outage, but restarting requires
 # online license verification. Test the same JVM/network properties first.
 $probeFile=Join-Path $RunDirectory 'MemoryConnectivityProbe.java'
 @'
import java.net.*;
public class MemoryConnectivityProbe {
 public static void main(String[] args) throws Exception {
  HttpURLConnection c=(HttpURLConnection)URI.create("https://licenses.strategyquant.com/").toURL().openConnection();
  c.setRequestMethod("HEAD");c.setConnectTimeout(5000);c.setReadTimeout(7000);
  int code=c.getResponseCode();c.disconnect();
  if(code<200 || code>=400) throw new Exception("License-site connectivity probe HTTP "+code);
  System.out.println("License-site connectivity probe passed: HTTP "+code);
 }
}
'@ | Set-Content -LiteralPath $probeFile -Encoding ASCII
 $networkOptions=@($oldLines | Where-Object {$_ -match '^option\s+-D(java.net.useSystemProxies|http.nonProxyHosts|https?.proxyHost|https?.proxyPort)='} | ForEach-Object {$_ -replace '^option\s+',''})
 $probeInfo=New-Object Diagnostics.ProcessStartInfo
 $probeInfo.FileName=Join-Path $install 'j64\bin\java.exe'
 $probeInfo.Arguments='-Xms32m -Xmx96m '+($networkOptions -join ' ')+' "'+$probeFile+'"'
 $probeInfo.WorkingDirectory=$install;$probeInfo.UseShellExecute=$false;$probeInfo.CreateNoWindow=$true
 $probeInfo.RedirectStandardOutput=$true;$probeInfo.RedirectStandardError=$true
 $probeProcess=[Diagnostics.Process]::Start($probeInfo)
 $probeOut=$probeProcess.StandardOutput.ReadToEnd();$probeError=$probeProcess.StandardError.ReadToEnd();$probeProcess.WaitForExit()
 ($probeOut+$probeError) | Set-Content (Join-Path $RunDirectory 'license-connectivity-probe.txt')
 if($probeProcess.ExitCode -ne 0){throw 'License-site connectivity failed; SQX was left running with its original profile'}
 Write-MemoryLog 'License-site connectivity confirmed before stopping SQX'
 (Invoke-MemoryApi '-project action=status name=S001_reproduce_project') | Set-Content (Join-Path $RunDirectory 'status-before.txt')
 $beforeBanks=Invoke-MemoryApi '-databank action=list project=S001_reproduce_project'
 $beforeBanks | Set-Content (Join-Path $RunDirectory 'banks-before.txt')
 Write-MemoryLog 'Stopping S001 gracefully and saving its banks'
 $stopped=Invoke-MemoryApi '-project action=stop name=S001_reproduce_project'
 if($stopped -notmatch 'Project execution stopped'){throw 'S001 stop was not confirmed'}
 try{Write-MemoryLog (Invoke-MemoryApi '-exit')}catch{Write-MemoryLog ('Exit request connection: '+$_.Exception.Message)}
 $deadline=(Get-Date).AddMinutes(3)
 while(Get-Process -Id $oldPID -ErrorAction SilentlyContinue){if((Get-Date) -gt $deadline){throw 'SQX did not exit; no force stop was attempted'};Start-Sleep -Seconds 1}
 $oldExited=$true
 Write-MemoryLog 'Old engine exited; backing up saved project and all historical bank folders'
 $backup=Join-Path $RunDirectory 'saved-project'
 Copy-Item -LiteralPath $project -Destination $backup -Recurse
 $hashes=@(Get-ChildItem -LiteralPath $project -File -Recurse -Filter '*.sqx' | ForEach-Object {
  $relative=$_.FullName.Substring($project.Length+1)
  $hash=(Get-FileHash -LiteralPath $_.FullName).Hash
  if((Get-FileHash -LiteralPath (Join-Path $backup $relative)).Hash -ne $hash){throw ('Backup verification failed: '+$relative)}
  [pscustomobject]@{Relative=$relative;SHA256=$hash}
 })
 $hashes | Export-Csv (Join-Path $RunDirectory 'protected-files.csv') -NoTypeInformation
 $savedHash=(Get-FileHash -LiteralPath (Join-Path $project 'project.cfx')).Hash
 if($savedHash -ne (Get-FileHash -LiteralPath (Join-Path $backup 'project.cfx')).Hash){throw 'Project backup hash mismatch'}
 if(Get-Process sqcli,StrategyQuantX,StrategyQuantX_ui -ErrorAction SilentlyContinue){throw 'Another SQX engine appeared during maintenance'}
 $newLines=@($oldLines | ForEach-Object {
  if($_ -match '^option\s+-Xms'){'option -Xms20g'}
  elseif($_ -match '^option\s+-Xmx'){"option -Xmx${MaximumHeapGB}g"}
  elseif($_ -match '^option\s+-XX:GCTimeRatio=' -or $_ -match '^option\s+-Xlog:gc'){ }
  else{$_}
 })+@('option -XX:GCTimeRatio=99','option -Xlog:gc*:file=user/log/sqx-memory-%p.log:time,uptime,level,tags:filecount=3,filesize=10M')
 $temporary=$config+'.memory-'+[guid]::NewGuid().ToString('N')+'.tmp'
 [IO.File]::WriteAllLines($temporary,[string[]]$newLines,[Text.UTF8Encoding]::new($false))
 [IO.File]::Replace($temporary,$config,(Join-Path $RunDirectory 'sqcli.config.replaced'))
 $configChanged=$true
 Set-PreparedCurrentRun
 Write-MemoryLog ('Verified '+$hashes.Count+' saved strategy files; prepared existing run '+$originalRun+' without rebuilding banks')
 $deadline=(Get-Date).AddSeconds(30)
 while((Get-ScheduledTask -TaskName $taskName).State -eq 'Running'){if((Get-Date) -gt $deadline){throw 'Original launcher has not finished exiting'};Start-Sleep -Seconds 1}
 Start-ScheduledTask -TaskName $taskName
 $deadline=(Get-Date).AddMinutes(3);$newEngine=$null;$afterBanks=$null
 do {
  Start-Sleep -Seconds 3
  $newEngine=Get-Process sqcli -ErrorAction SilentlyContinue
  if($newEngine){try{$afterBanks=Invoke-MemoryApi '-databank action=list project=S001_reproduce_project'}catch{Write-MemoryLog 'Waiting for the restarted engine API'}}
 }while(-not $afterBanks -and (Get-Date) -lt $deadline)
 if(-not $newEngine -or -not $afterBanks){throw 'Restarted SQX API was not confirmed'}
 # The API becomes reachable before asynchronous databank loading finishes.
 $loadDeadline=(Get-Date).AddMinutes(3)
 do {
  $banksLoaded=$true
  foreach($line in ($beforeBanks -split "`n")){
   if($line -match '^(S001_build_[^,]+), Records: (\d+)'){
    $match=[regex]::Match($afterBanks,'(?m)^'+[regex]::Escape($matches[1])+', Records: (\d+)')
    if(-not $match.Success -or [int]$match.Groups[1].Value -lt [int]$matches[2]){$banksLoaded=$false}
   }
  }
  if(-not $banksLoaded){
   if((Get-Date) -gt $loadDeadline){throw 'Timed out waiting for saved build banks to load'}
   Start-Sleep -Seconds 3
   $afterBanks=Invoke-MemoryApi '-databank action=list project=S001_reproduce_project'
  }
 }while(-not $banksLoaded)

 $afterState=Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
 if($afterState.Run -ne $originalRun){throw 'The launcher created a different run instead of reusing current banks'}
 foreach($key in $prior.BankMap.PSObject.Properties.Name){if($afterState.BankMap.$key -ne $prior.BankMap.$key){throw ('Bank map changed: '+$key)}}
 foreach($line in ($beforeBanks -split "`n")){
  if($line -match '^(S001_build_[^,]+), Records: (\d+)'){
   $bank=$matches[1];$minimum=[int]$matches[2]
   $afterMatch=[regex]::Match($afterBanks,'(?m)^'+[regex]::Escape($bank)+', Records: (\d+)')
   if(-not $afterMatch.Success -or [int]$afterMatch.Groups[1].Value -lt $minimum){throw ('Build-bank count decreased: '+$bank)}
  }
 }
 foreach($file in $hashes){if((Get-FileHash -LiteralPath (Join-Path $project $file.Relative)).Hash -ne $file.SHA256){throw ('Protected file changed: '+$file.Relative)}}
 if((Get-FileHash -LiteralPath (Join-Path $project 'project.cfx')).Hash -ne $savedHash){throw 'Project configuration changed during memory-only restart'}
 (Invoke-MemoryApi '-project action=status name=S001_reproduce_project') | Set-Content (Join-Path $RunDirectory 'status-after.txt')
 $afterBanks | Set-Content (Join-Path $RunDirectory 'banks-after.txt')
 [pscustomobject]@{CompletedAt=(Get-Date).ToString('o');OldPID=$oldPID;NewPID=$newEngine.Id;Run=$originalRun;InitialHeapGB=20;MaximumHeapGB=$MaximumHeapGB;GCTimeRatio=99;ProtectedStrategyFiles=$hashes.Count;ProjectHash=$savedHash;ConfigHash=(Get-FileHash $config).Hash;BankMapUnchanged=$true} | ConvertTo-Json | Set-Content (Join-Path $RunDirectory 'memory-change-complete.json') -Encoding UTF8
 Write-MemoryLog 'COMPLETE: S001 restarted with the same run and all protected files unchanged'
}catch{
 ($_ | Out-String) | Add-Content (Join-Path $RunDirectory 'maintenance-errors.txt')
 Write-MemoryLog ('FAILED '+$_.Exception.Message)
 if($oldExited -and -not (Get-Process sqcli -ErrorAction SilentlyContinue)){
  if($configChanged){Copy-Item -LiteralPath (Join-Path $RunDirectory 'sqcli.config.before') -Destination $config -Force}
  Set-PreparedCurrentRun
  Start-ScheduledTask -TaskName $taskName
  Write-MemoryLog 'Started original profile recovery using the same prepared bank map'
 }
 throw
}
