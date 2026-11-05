param(
    [Parameter(Mandatory = $true)][string]$SourceProject,
    [Parameter(Mandatory = $true)][string]$OutputProject,
    [string]$OldBase = 'C:\Users\victo\Documents\quantatative_analysis',
    [string]$TemplateDir = 'C:\StrategyQuantX144\user\settings\StrategyTemplates',
    [string]$OutputDir = 'C:\StrategyQuantX144\user\S001_sys_parameters',
    [string]$CompareProject,
    [string]$TaskFile,
    [string]$TemplateFile,
    [string]$OldInstallBase,
    [string]$NewInstallBase
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$latin1 = [Text.Encoding]::GetEncoding(28591)

$replacements = [ordered]@{
    (Join-Path $OldBase 'AItemplate_Breakout_SP500_template.sqx') = Join-Path $TemplateDir 'AItemplate_Breakout_SP500_template.sqx'
    (Join-Path $OldBase 'S001_random_group_template_20260925.sqx') = Join-Path $TemplateDir 'S001_random_group_template_20260925.sqx'
    (Join-Path $OldBase 'S001_entry_revised_template.sqx') = Join-Path $TemplateDir 'S001_entry_revised_template.sqx'
    (Join-Path $OldBase 'S001_sys_parameters') = $OutputDir
}

function Read-EntryBytes($entry) {
    $stream = $entry.Open()
    $ms = New-Object IO.MemoryStream
    $stream.CopyTo($ms)
    $stream.Close()
    return $ms.ToArray()
}

$src = [IO.Compression.ZipFile]::OpenRead($SourceProject)
try {
    $compare = $null
    if ($CompareProject) {
        $compare = [IO.Compression.ZipFile]::OpenRead($CompareProject)
    }

    if (Test-Path -LiteralPath $OutputProject) {
        Remove-Item -LiteralPath $OutputProject -Force
    }
    $dst = [IO.Compression.ZipFile]::Open($OutputProject, 'Create')
    $mismatch = 0
    $changed = 0
    try {
        foreach ($entry in $src.Entries) {
            $bytes = Read-EntryBytes $entry
            if ($entry.FullName -like '*.xml') {
                $text = $latin1.GetString($bytes)
                $new = $text
                foreach ($key in $replacements.Keys) {
                    $new = $new.Replace($key, $replacements[$key])
                }
                if ($TaskFile -and $TemplateFile -and $entry.FullName -eq $TaskFile) {
                    $replacement = 'templateFile="' + $TemplateFile + '"'
                    $new = [regex]::Replace($new, 'templateFile="[^"]*"', $replacement)
                }
                if ($OldInstallBase -and $NewInstallBase) {
                    $new = $new.Replace($OldInstallBase, $NewInstallBase)
                }
                if ($new -ne $text) { $changed++ }
                $bytes = $latin1.GetBytes($new)

                if ($compare) {
                    $ce = $compare.GetEntry($entry.FullName)
                    if ($ce) {
                        $cb = Read-EntryBytes $ce
                        if ([Convert]::ToBase64String($cb) -ne [Convert]::ToBase64String($bytes)) {
                            $mismatch++
                            Write-Output "CONTENT_MISMATCH: $($entry.FullName)"
                        }
                    }
                }
            }
            $ne = $dst.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::Optimal)
            $os = $ne.Open()
            $os.Write($bytes, 0, $bytes.Length)
            $os.Close()
        }
    } finally {
        $dst.Dispose()
        if ($compare) { $compare.Dispose() }
    }
} finally {
    $src.Dispose()
}

$out = [IO.Compression.ZipFile]::OpenRead($OutputProject)
$left = @()
try {
    foreach ($entry in $out.Entries) {
        if ($entry.FullName -notlike '*.xml') { continue }
        $text = $latin1.GetString((Read-EntryBytes $entry))
        if ($text.Contains($OldBase)) { $left += $entry.FullName }
    }
} finally {
    $out.Dispose()
}

Write-Output "entriesChanged=$changed"
Write-Output "contentMismatches=$mismatch"
Write-Output "entriesWithOldBase=$($left.Count)"
Write-Output "output=$OutputProject"
