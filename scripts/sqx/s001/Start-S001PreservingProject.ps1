#requires -Version 5.1
<#
.SYNOPSIS
Prepares backed-up, versioned S001 databanks and starts SQX 145. Task Scheduler payload for ERAZER.
.DESCRIPTION
Saved from the verified S001 revision 2 deployment on 2026-10-20.
See docs/s001-operations.md for dependencies and execution boundaries.
#>
param([switch]$PrepareOnly)
$ProgressPreference='SilentlyContinue';$ErrorActionPreference='Stop'
$project='C:\StrategyQuantX145\user\projects\S001_reproduce_project'
$tool='C:\Users\Vic\ERAZER-Tools\SQX'
$blueprint=Join-Path $tool 'S001-preservation-blueprint.cfx'
$manifest=Get-Content (Join-Path $tool 'S001-preservation-manifest.json') -Raw | ConvertFrom-Json
$ledger=Join-Path $tool 'S001-preservation-last-run.json'
$log='C:\Users\Vic\ERAZER-Tools\Logs\S001-preservation-launch.log'
function Log($s){((Get-Date -Format o)+' '+$s) | Add-Content -LiteralPath $log}
try {
 if($env:COMPUTERNAME -ne 'ERAZER-6JMHAKCD'){throw 'Wrong host'}
 if(Get-Process sqcli,StrategyQuantX,StrategyQuantX_ui -ErrorAction SilentlyContinue){throw 'SQX instance already exists'}
 if((Get-FileHash $blueprint -Algorithm SHA256).Hash -ne $manifest.blueprintSha256){throw 'Blueprint does not match its reviewed manifest'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $prior=$null;if(Test-Path $ledger){$prior=Get-Content $ledger -Raw | ConvertFrom-Json}
 $live=Join-Path $project 'project.cfx'
 $reuse=($prior -and $prior.Revision -eq 2 -and $prior.BlueprintHash -eq $manifest.blueprintSha256 -and $prior.PreparedForLaunch -and ((Get-FileHash $live -Algorithm SHA256).Hash -eq $prior.ProjectHash))
 if(-not $reuse){
  $run=Get-Date -Format 'yyyyMMddHHmmssfff'
  $backup='C:\Users\Vic\ERAZER-Tools\Backups\S001-runs\before-'+$run
  New-Item -ItemType Directory -Path ($backup+'\databanks') -Force | Out-Null
  Copy-Item -LiteralPath $live -Destination ($backup+'\project.cfx')
  if(Test-Path $ledger){Copy-Item $ledger ($backup+'\previous-run.json')}
  $zip=[IO.Compression.ZipFile]::OpenRead($live)
  try{$reader=New-Object IO.StreamReader($zip.GetEntry('config.xml').Open());try{$old=New-Object Xml.XmlDocument;$old.LoadXml($reader.ReadToEnd())}finally{$reader.Dispose()}}finally{$zip.Dispose()}
  foreach($bank in $old.Project.Databanks.Databank){
   $path=Join-Path $project ('databanks\'+$bank.name)
   if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination ($backup+'\databanks\'+$bank.name) -Recurse}
  }
  Get-ChildItem ($backup+'\databanks') -File -Recurse -Filter '*.sqx' | ForEach-Object {
   $relative=$_.FullName.Substring($backup.Length+1);$hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
   if((Get-FileHash -LiteralPath (Join-Path $project $relative) -Algorithm SHA256).Hash -ne $hash){throw 'Pre-run backup hash mismatch'}
   [pscustomobject]@{Relative=$relative;SHA256=$hash}
  } | Export-Csv ($backup+'\files.csv') -NoTypeInformation
  Log ('Pre-run backup verified: '+$backup)
  $map=@{};foreach($name in $manifest.newDatabanks){$map[$name]=$name+'__r'+$run}
  $namespace=Get-Content (Join-Path $tool 'Namespace-SqxFiles.ps1') -Raw
  foreach($base in @('S001_build_01_template','S001_build_02_random','S001_build_10_sp500')){
   $source=$null
   if($prior -and $prior.BankMap.$base){$candidate=Join-Path $project ('databanks\'+$prior.BankMap.$base);if(@(Get-ChildItem -LiteralPath $candidate -File -Filter '*.sqx' -ErrorAction SilentlyContinue).Count){$source=$candidate}}
   if(-not $source -and $base -eq 'S001_build_01_template'){$source=Join-Path $project 'databanks\databank1_S001_use_nasdaq100'}
   if(-not $source -and $base -eq 'S001_build_10_sp500'){$source=Join-Path $project 'databanks\sp500_example_strategy'}
   $destination=Join-Path $project ('databanks\'+$map[$base])
   if(Test-Path $destination){throw 'Run-bank collision'}
   New-Item -ItemType Directory -Path $destination | Out-Null
   if($source){$prefix=@{'S001_build_01_template'='B01';'S001_build_02_random'='B02';'S001_build_10_sp500'='B03'}[$base];& ([scriptblock]::Create($namespace)) -Source $source -Destination $destination -Prefix $prefix}
  }
  $temporary=Join-Path $project ('.preserve-v2-'+$run+'.tmp')
  $blueprintZip=[IO.Compression.ZipFile]::OpenRead($blueprint)
  try{$materializedZip=[IO.Compression.ZipFile]::Open($temporary,[IO.Compression.ZipArchiveMode]::Create)
   try{foreach($entry in $blueprintZip.Entries){
    $reader=New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8)
    try{$doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.LoadXml($reader.ReadToEnd())}finally{$reader.Dispose()}
    foreach($attr in $doc.SelectNodes('//@*')){if($map.ContainsKey($attr.Value)){$attr.Value=$map[$attr.Value]}}
    foreach($node in $doc.SelectNodes('//*[not(*)]')){if($map.ContainsKey($node.InnerText)){$node.InnerText=$map[$node.InnerText]}}
    $e=$materializedZip.CreateEntry($entry.FullName,[IO.Compression.CompressionLevel]::Optimal)
    $writer=New-Object IO.StreamWriter($e.Open(),[Text.UTF8Encoding]::new($false));try{$writer.Write($doc.OuterXml)}finally{$writer.Dispose()}
   }}finally{$materializedZip.Dispose()}
  }finally{$blueprintZip.Dispose()}
  $check=[IO.Compression.ZipFile]::OpenRead($temporary)
  try{foreach($e in $check.Entries){$reader=New-Object IO.StreamReader($e.Open());try{$doc=New-Object Xml.XmlDocument;$doc.LoadXml($reader.ReadToEnd())}finally{$reader.Dispose()}}}finally{$check.Dispose()}
  [IO.File]::Replace($temporary,$live,($live+'.before-review-v2-'+$run))
  $state=[ordered]@{Revision=2;Run=$run;BlueprintHash=$manifest.blueprintSha256;BankMap=$map;ProjectHash=(Get-FileHash $live -Algorithm SHA256).Hash;PreparedForLaunch=$true;PreRunBackup=$backup}
  $json=$state | ConvertTo-Json -Depth 4
  $json | Set-Content $ledger -Encoding UTF8;$json | Set-Content (Join-Path $tool ('S001-run-'+$run+'.json')) -Encoding UTF8
  Log ('Prepared revision 2, run '+$run+'; '+$map.Count+' working banks, all prior files retained')
 }
 # Archive setup happens once before the project starts, so Task 1 is the first build.
 & ([scriptblock]::Create((Get-Content (Join-Path $tool 'Start-S001ArchiveRun.ps1') -Raw)))
 if($PrepareOnly){Log 'Revision 2 prepared without launching';exit 0}
 $state=Get-Content $ledger -Raw | ConvertFrom-Json;$state.PreparedForLaunch=$false
 $state | ConvertTo-Json -Depth 4 | Set-Content $ledger -Encoding UTF8
 $stdout='C:\Users\Vic\ERAZER-Tools\Logs\sqx145-task1-start.txt';$stderr=$stdout+'.err';$stamp=Get-Date -Format yyyyMMdd-HHmmssfff
 foreach($f in @($stdout,$stderr)){if(Test-Path $f){Copy-Item -LiteralPath $f -Destination ($f+'.before-'+$stamp)}}
 $p=Start-Process C:\StrategyQuantX145\sqcli.exe -ArgumentList '-project action=startFromTask name=S001_reproduce_project task=1' -WorkingDirectory C:\StrategyQuantX145 -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 Log ('Started revised S001 from Task 1, PID '+$p.Id)
 Start-Sleep -Seconds 3;try{(Get-Process -Id $p.Id -ErrorAction Stop).PriorityClass='High'}catch{Log 'Priority could not be set'}
 $p.WaitForExit();Log ('SQX exited: '+$p.ExitCode);exit $p.ExitCode
}catch{Log ('FAILED '+($_ | Out-String));throw}
