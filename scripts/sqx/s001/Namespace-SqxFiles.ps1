#requires -Version 5.1
<#
.SYNOPSIS
Copies S001 strategy archives with collision-safe builder names and verifies strategy content.
.DESCRIPTION
Saved from the verified S001 revision 2 deployment on 2026-10-20.
See docs/s001-operations.md for dependencies and execution boundaries.
#>
param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Destination,[Parameter(Mandatory)][ValidatePattern('^B0[123]$')][string]$Prefix,[string]$Marker,[int]$MinimumCount=0)
$ProgressPreference='SilentlyContinue';$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$records=@();$count=0
$sourceFiles=@(Get-ChildItem -LiteralPath $Source -File -Filter '*.sqx')
if($sourceFiles.Count -lt $MinimumCount){throw ('Expected at least '+$MinimumCount+' archived strategies; found '+$sourceFiles.Count)}
foreach($file in $sourceFiles) {
 $sourceHash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
 $inputZip=[IO.Compression.ZipFile]::OpenRead($file.FullName)
 try {
  $entry=$inputZip.GetEntry('settings.xml');if(-not $entry){throw ('Missing settings.xml: '+$file.Name)}
  $reader=New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8)
  try{$xml=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $pattern=[regex]'(<ResultsGroup\b[^>]*\bResultName=")([^"]*)(")'
  $match=$pattern.Match($xml);if(-not $match.Success){throw 'ResultName missing'}
  $name=[Net.WebUtility]::HtmlDecode($match.Groups[2].Value)
  $newName=if($name -match ('^'+$Prefix+'__.+__[a-f0-9]{16}$')){$name}else{$Prefix+'__'+$name+'__'+$sourceHash.Substring(0,16)}
  if($newName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0){throw 'Unsafe strategy filename'}
  $target=Join-Path $Destination ($newName+'.sqx')
  if(Test-Path -LiteralPath $target){throw ('Refusing namespace collision: '+$target)}
  if($newName -eq $name){
   Copy-Item -LiteralPath $file.FullName -Destination $target
   if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash){throw 'Namespaced copy hash mismatch'}
   $records += [pscustomobject]@{Original=$name;Namespaced=$newName;SourceSHA256=$sourceHash};$count++;continue
  }
  $newXml=$pattern.Replace($xml,[Text.RegularExpressions.MatchEvaluator]{param($m) $m.Groups[1].Value+[Security.SecurityElement]::Escape($newName)+$m.Groups[3].Value},1)
  $temp=$target+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  $outputZip=[IO.Compression.ZipFile]::Open($temp,[IO.Compression.ZipArchiveMode]::Create)
  try {foreach($e in $inputZip.Entries){
   $newEntry=$outputZip.CreateEntry($e.FullName,[IO.Compression.CompressionLevel]::Optimal);$newEntry.LastWriteTime=$e.LastWriteTime
   $out=$newEntry.Open()
   try{if($e.FullName -eq 'settings.xml'){$b=[Text.UTF8Encoding]::new($false).GetBytes($newXml);$out.Write($b,0,$b.Length)}else{$inside=$e.Open();try{$inside.CopyTo($out)}finally{$inside.Dispose()}}}finally{$out.Dispose()}
  }}finally{$outputZip.Dispose()}
  # Verify every strategy definition and binary result stream was copied intact.
  $check=[IO.Compression.ZipFile]::OpenRead($temp)
  try {foreach($e in $inputZip.Entries){if($e.FullName -ne 'settings.xml'){
   $a=$e.Open();$b=$check.GetEntry($e.FullName).Open();$sha=[Security.Cryptography.SHA256]::Create()
   try{$ha=[Convert]::ToBase64String($sha.ComputeHash($a));$hb=[Convert]::ToBase64String($sha.ComputeHash($b));if($ha -ne $hb){throw 'Strategy content changed during namespacing'}}finally{$a.Dispose();$b.Dispose();$sha.Dispose()}
  }}}finally{$check.Dispose()}
  [IO.File]::Move($temp,$target)
  $records += [pscustomobject]@{Original=$name;Namespaced=$newName;SourceSHA256=$sourceHash}
  $count++
 }finally{$inputZip.Dispose()}
}
$records | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $Destination ('provenance-'+$Prefix+'.json')) -Encoding UTF8
if($Marker){[IO.File]::WriteAllText($Marker,('Verified '+$count+' strategy copies'))}
Write-Output ('Namespaced '+$count+' strategies with '+$Prefix+'; original files and strategy definitions retained.')
