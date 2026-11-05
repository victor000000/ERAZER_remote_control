function New-SqxProjectArchive {
    <#
    .SYNOPSIS
    Rebuilds an SQX .cfx as a new ZIP without modifying its source.
    .DESCRIPTION
    Replacements are literal, unescaped paths, applied only to XML entries. Their
    XML-escaped forms are substituted using byte-preserving Latin1 decoding.
    TaskFile names an exact ZIP entry; TemplateFile overrides its templateFile
    attribute. Both must be supplied together.

    CompareProject must be a distinct archive containing the EXPECTED TRANSFORMED
    content, not the original source. Entry names and all uncompressed bytes must
    match, including binary entries, empty entries, missing entries and extras.
    Any mismatch throws before publication. ZIP metadata/compression may differ.

    A unique sibling temporary ZIP is closed and verified before publication.
    Existing output requires -Force and is backed up by the atomic File.Replace
    operation. On validation failure the existing output is left untouched.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceProject,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputProject,
        [hashtable]$Replacements = @{},
        [string]$TaskFile,
        [string]$TemplateFile,
        [string]$CompareProject,
        [switch]$Force
    )

    function Resolve-ArchivePath {
        param([string]$Path, [switch]$MustExist)
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $fullPath = [IO.Path]::GetFullPath($fullPath)
        if (Test-Path -LiteralPath $fullPath) {
            $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
            if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer) {
                throw "Archive path must name a file: $Path"
            }
            return $item.FullName
        }
        if ($MustExist) { throw "Archive does not exist: $Path" }
        $parent = Get-Item -LiteralPath ([IO.Path]::GetDirectoryName($fullPath)) -Force -ErrorAction Stop
        if ($parent.PSProvider.Name -ne 'FileSystem' -or -not $parent.PSIsContainer) {
            throw "Output parent must be an existing filesystem directory: $Path"
        }
        return [IO.Path]::Combine($parent.FullName, [IO.Path]::GetFileName($fullPath))
    }

    function Get-ArchiveFileIdentity {
        param([string]$Path)
        # A path comparison alone misses Windows hard links and symbolic links.
        # This is an identity check, not protection against hostile concurrent
        # filesystem changes between validation and atomic publication.
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
            -not [IO.File]::Exists($Path)) { return $null }
        if (-not ('ERAZER.SqxArchiveFileIdentity' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace ERAZER {
    public static class SqxArchiveFileIdentity {
        [StructLayout(LayoutKind.Sequential)]
        private struct FileInformation {
            public uint Attributes;
            public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
            public uint VolumeSerialNumber, FileSizeHigh, FileSizeLow, NumberOfLinks;
            public uint FileIndexHigh, FileIndexLow;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(
            SafeFileHandle handle, out FileInformation information);
        public static string Get(SafeFileHandle handle) {
            FileInformation information;
            if (!GetFileInformationByHandle(handle, out information))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return String.Format("{0:X8}:{1:X8}{2:X8}", information.VolumeSerialNumber,
                information.FileIndexHigh, information.FileIndexLow);
        }
    }
}
'@ -ErrorAction Stop
        }
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try { return [ERAZER.SqxArchiveFileIdentity]::Get($stream.SafeFileHandle) }
        finally { $stream.Dispose() }
    }

    function Assert-DistinctArchivePaths {
        param([string[]]$Paths)
        for ($i = 0; $i -lt $Paths.Count; $i++) {
            for ($j = $i + 1; $j -lt $Paths.Count; $j++) {
                if ([string]::Equals($Paths[$i], $Paths[$j], [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'SourceProject, OutputProject and CompareProject must be distinct files (same path rejected).'
                }
                $firstIdentity = Get-ArchiveFileIdentity $Paths[$i]
                $secondIdentity = Get-ArchiveFileIdentity $Paths[$j]
                if ($null -ne $firstIdentity -and $firstIdentity -eq $secondIdentity) {
                    throw 'SourceProject, OutputProject and CompareProject must be distinct files (same file alias rejected).'
                }
            }
        }
    }

    function Read-ArchiveEntryBytes {
        param([IO.Compression.ZipArchiveEntry]$Entry)
        $stream = $Entry.Open()
        try {
            $memory = New-Object IO.MemoryStream
            try {
                $stream.CopyTo($memory)
                # Do not let PowerShell enumerate byte arrays: empty entries must
                # return a real byte[0], rather than $null.
                return ,($memory.ToArray())
            }
            finally { $memory.Dispose() }
        }
        finally { $stream.Dispose() }
    }

    function Get-BytesFingerprint {
        param([byte[]]$Bytes)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return [Convert]::ToBase64String($sha.ComputeHash($Bytes)) }
        finally { $sha.Dispose() }
    }

    function Get-ArchiveIndex {
        param([string]$Path)
        $index = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($entry in $archive.Entries) {
                if ($index.ContainsKey($entry.FullName)) { throw "Duplicate ZIP entry: $($entry.FullName)" }
                $bytes = Read-ArchiveEntryBytes $entry
                $index.Add($entry.FullName, (Get-BytesFingerprint $bytes))
            }
        }
        finally { $archive.Dispose() }
        return ,$index
    }

    function Get-ArchiveMismatches {
        param($Expected, $Actual)
        $mismatches = [Collections.Generic.List[string]]::new()
        foreach ($name in $Expected.Keys) {
            if (-not $Actual.ContainsKey($name)) { $mismatches.Add("missing: $name") }
            elseif ($Expected[$name] -cne $Actual[$name]) { $mismatches.Add("content: $name") }
        }
        foreach ($name in $Actual.Keys) {
            if (-not $Expected.ContainsKey($name)) { $mismatches.Add("extra: $name") }
        }
        return ,$mismatches
    }

    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    if ([bool]$TaskFile -ne [bool]$TemplateFile) { throw 'TaskFile and TemplateFile must be supplied together.' }
    $sourcePath = Resolve-ArchivePath $SourceProject -MustExist
    $outputPath = Resolve-ArchivePath $OutputProject
    $comparePath = $null
    $paths = @($sourcePath, $outputPath)
    if ($CompareProject) {
        $comparePath = Resolve-ArchivePath $CompareProject -MustExist
        $paths += $comparePath
    }
    Assert-DistinctArchivePaths $paths
    if ([IO.File]::Exists($outputPath) -and -not $Force) {
        throw 'OutputProject already exists. Specify -Force to overwrite it with a backup.'
    }

    # Exception fallback prevents silent '?' substitution for new paths outside
    # Latin1. Existing bytes always round-trip, regardless of the XML encoding.
    $latin1 = [Text.Encoding]::GetEncoding(28591,
        [Text.EncoderExceptionFallback]::new(), [Text.DecoderExceptionFallback]::new())
    $substitutions = @(
        foreach ($key in $Replacements.Keys) {
            if ([string]::IsNullOrEmpty([string]$key) -or $null -eq $Replacements[$key]) {
                throw 'Replacement keys must be nonempty and replacement values must not be null.'
            }
            if ([string]$key -match '[^\x00-\x7F]' -or [string]$Replacements[$key] -match '[^\x00-\x7F]') {
                throw 'Byte-preserving path substitutions require ASCII replacement paths; XML encoding conversion is not supported.'
            }
            [pscustomobject]@{
                Old = [Security.SecurityElement]::Escape([string]$key)
                New = [Security.SecurityElement]::Escape([string]$Replacements[$key])
            }
        }
    )
    # More-specific paths win over a shorter base path supplied in the same map.
    $substitutions = @($substitutions | Sort-Object @{ Expression = { $_.Old.Length }; Descending = $true }, Old)
    if ($TemplateFile -match '[^\x00-\x7F]') { throw 'TemplateFile must be an ASCII path for a byte-preserving rebuild.' }
    $escapedTemplate = if ($TemplateFile) { [Security.SecurityElement]::Escape($TemplateFile) } else { $null }
    $templatePattern = [regex]'(?<prefix>\btemplateFile\s*=\s*)(?<quote>["''])(?<value>.*?)\k<quote>'

    if (-not $PSCmdlet.ShouldProcess($outputPath, 'Publish verified SQX archive (back up existing output if present)')) {
        return
    }

    $temporaryPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($outputPath),
        ('.' + [IO.Path]::GetFileName($outputPath) + '.' + [guid]::NewGuid().ToString('N') + '.tmp'))
    $backupPath = $null
    $changed = 0
    $entryCount = 0
    $taskMatched = $false
    $expected = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    try {
        $source = [IO.Compression.ZipFile]::OpenRead($sourcePath)
        try {
            $file = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                $destination = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $true)
                try {
                    foreach ($entry in $source.Entries) {
                        if ($expected.ContainsKey($entry.FullName)) { throw "Duplicate ZIP entry: $($entry.FullName)" }
                        $bytes = Read-ArchiveEntryBytes $entry
                        if ($entry.FullName.EndsWith('.xml', [StringComparison]::OrdinalIgnoreCase)) {
                            $text = $latin1.GetString($bytes)
                            $newText = $text
                            foreach ($replacement in $substitutions) {
                                $newText = $newText.Replace($replacement.Old, $replacement.New)
                            }
                            if ($TaskFile -and [string]::Equals($entry.FullName, $TaskFile, [StringComparison]::Ordinal)) {
                                if (-not $templatePattern.IsMatch($newText)) {
                                    throw "TaskFile has no templateFile attribute: $TaskFile"
                                }
                                # MatchEvaluator returns literal text: '$1', '${name}'
                                # and '$&' in a path are never regex replacement tokens.
                                $newText = $templatePattern.Replace($newText, [Text.RegularExpressions.MatchEvaluator]{
                                    param($match)
                                    $match.Groups['prefix'].Value + $match.Groups['quote'].Value +
                                        $escapedTemplate + $match.Groups['quote'].Value
                                })
                                $taskMatched = $true
                            }
                            if (-not [string]::Equals($newText, $text, [StringComparison]::Ordinal)) { $changed++ }
                            $bytes = $latin1.GetBytes($newText)
                        }
                        $expected.Add($entry.FullName, (Get-BytesFingerprint $bytes))
                        $newEntry = $destination.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::Optimal)
                        $newEntry.LastWriteTime = $entry.LastWriteTime
                        $newEntry.ExternalAttributes = $entry.ExternalAttributes
                        $stream = $newEntry.Open()
                        try { $stream.Write($bytes, 0, $bytes.Length) }
                        finally { $stream.Dispose() }
                        $entryCount++
                    }
                    if ($TaskFile -and -not $taskMatched) { throw "TaskFile XML entry was not found: $TaskFile" }
                }
                finally { $destination.Dispose() }
            }
            finally { $file.Dispose() }
        }
        finally { $source.Dispose() }

        $verified = Get-ArchiveIndex $temporaryPath
        $verificationErrors = Get-ArchiveMismatches $expected $verified
        if ($verificationErrors.Count) {
            throw "Temporary archive validation failed: $($verificationErrors -join '; ')"
        }
        if ($comparePath) {
            $comparison = Get-ArchiveIndex $comparePath
            # Treat CompareProject as expected, so diagnostics describe entries
            # missing from / extra in the newly rebuilt archive.
            $comparisonErrors = Get-ArchiveMismatches $comparison $verified
            if ($comparisonErrors.Count) {
                throw "CompareProject comparison validation failed ($($comparisonErrors.Count)): $($comparisonErrors -join '; ')"
            }
        }

        # Recheck immediately before publication, including an output created
        # while the new ZIP was being built. No destructive Remove-Item step.
        Assert-DistinctArchivePaths $paths
        if ([IO.File]::Exists($outputPath)) {
            if (-not $Force) { throw 'OutputProject now exists. Specify -Force to overwrite it with a backup.' }
            $backupPath = $outputPath + '.' + [guid]::NewGuid().ToString('N') + '.bak'
            [IO.File]::Replace($temporaryPath, $outputPath, $backupPath)
        }
        else {
            # The two-argument Move refuses to overwrite a racing creator.
            [IO.File]::Move($temporaryPath, $outputPath)
        }
        [pscustomobject]@{
            OutputProject = $outputPath
            EntriesChanged = $changed
            EntriesCount = $entryCount
            ContentMismatches = 0
            BackupPath = $backupPath
        }
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
    }
}
