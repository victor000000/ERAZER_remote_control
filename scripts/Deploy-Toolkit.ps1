[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param([Parameter(Mandatory)][string]$DestinationPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
if (-not [IO.Path]::IsPathRooted($DestinationPath)) { throw 'DestinationPath must be absolute.' }
$root = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd([IO.Path]::DirectorySeparatorChar)
$destination = [IO.Path]::GetFullPath($DestinationPath).TrimEnd([IO.Path]::DirectorySeparatorChar)
$separator = [IO.Path]::DirectorySeparatorChar
if ($destination -eq [IO.Path]::GetPathRoot($destination).TrimEnd($separator) -or
    $root.Equals($destination, [StringComparison]::OrdinalIgnoreCase) -or
    $root.StartsWith($destination + $separator, [StringComparison]::OrdinalIgnoreCase) -or
    $destination.StartsWith($root + $separator, [StringComparison]::OrdinalIgnoreCase)) { throw 'Choose a destination outside the source checkout, not a filesystem root or ancestor.' }
$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $root 'config/deployment.psd1')
foreach ($file in $manifest.Files) {
    $source = [IO.Path]::GetFullPath((Join-Path $root $file))
    if (-not $source.StartsWith($root + $separator, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Invalid deployment manifest source: $file" }
}
$marker = Join-Path $destination '.erazer-toolkit'
if (Test-Path -LiteralPath $destination) {
    if (-not $Force) { throw 'Destination exists. Use -Force only to replace a previously managed bundle.' }
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne 'ERAZER.RemoteControl.v1') { throw 'Refusing to overwrite an unmanaged directory.' }
}
if (-not $PSCmdlet.ShouldProcess($destination, 'Stage maintained toolkit bundle; no tasks or remote processes are changed')) { return }
$parent = Split-Path $destination -Parent
$null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
$staging = $destination + '.new-' + [Guid]::NewGuid().ToString('N')
$backup = $null
try {
    $null = New-Item -ItemType Directory -Path $staging -ErrorAction Stop
    foreach ($file in $manifest.Files) {
        $to = Join-Path $staging $file
        $null = New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force -ErrorAction Stop
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination $to -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $to).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root $file)).Hash) { throw 'Bundle copy verification failed.' }
    }
    [IO.File]::WriteAllText((Join-Path $staging '.erazer-toolkit'), 'ERAZER.RemoteControl.v1')
    if (Test-Path -LiteralPath $destination) { $backup = $destination + '.backup-' + [Guid]::NewGuid().ToString('N'); [IO.Directory]::Move($destination, $backup) }
    try { [IO.Directory]::Move($staging, $destination) }
    catch { if ($backup -and -not (Test-Path -LiteralPath $destination)) { [IO.Directory]::Move($backup, $destination) }; throw }
    [pscustomobject]@{ Destination=$destination; Files=$manifest.Files.Count; Backup=$backup; LiveDeployment=$false }
} finally { if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Stop } }
