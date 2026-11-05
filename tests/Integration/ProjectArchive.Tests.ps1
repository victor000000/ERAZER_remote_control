# Requires Pester 5.7.1. Fixtures are synthetic ZIPs under TestDrive only.
BeforeAll {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $modulePath = Join-Path $PSScriptRoot '../../src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    $latin1 = [Text.Encoding]::GetEncoding(28591)

    function New-TestArchive {
        param([string]$Path, [System.Collections.IDictionary]$Entries)
        $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in $Entries.Keys) {
                $entry = $archive.CreateEntry([string]$name)
                $stream = $entry.Open()
                try {
                    [byte[]]$bytes = $Entries[$name]
                    $stream.Write($bytes, 0, $bytes.Length)
                }
                finally { $stream.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }

    function Read-TestEntry {
        param([string]$Path, [string]$Name)
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $entry = $archive.GetEntry($Name)
            if ($null -eq $entry) { throw "Missing test entry: $Name" }
            $stream = $entry.Open()
            try {
                $memory = [IO.MemoryStream]::new()
                try {
                    $stream.CopyTo($memory)
                    return ,($memory.ToArray())
                }
                finally { $memory.Dispose() }
            }
            finally { $stream.Dispose() }
        }
        finally { $archive.Dispose() }
    }

    function Assert-NoTemporaryArchive {
        param([string]$Directory)
        @(Get-ChildItem -LiteralPath $Directory -Force -Filter '*.tmp').Count | Should -Be 0
    }
}

Describe 'New-SqxProjectArchive transactional ZIP rebuild' {
    BeforeEach {
        $caseDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $caseDirectory
        $sourcePath = Join-Path $caseDirectory 'source.cfx'
        $outputPath = Join-Path $caseDirectory '[output].cfx'
        $comparePath = Join-Path $caseDirectory 'expected.cfx'
        $binary = [byte[]](0, 255, 128, 1, 13, 10, 36, 38)
    }

    It 'keeps empty directories, empty XML/files and every untouched binary byte' {
        $xmlBytes = $latin1.GetBytes('<root value="unchanged" />') + [byte[]](128, 255)
        New-TestArchive $sourcePath ([ordered]@{
            'empty/' = [byte[]]@()
            'empty.xml' = [byte[]]@()
            'empty.bin' = [byte[]]@()
            'content.xml' = $xmlBytes
            'payload.bin' = $binary
        })
        $sourceBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath))

        $result = New-SqxProjectArchive -SourceProject $sourcePath -OutputProject $outputPath

        $result.OutputProject | Should -Be $outputPath
        $result.EntriesCount | Should -Be 5
        $result.EntriesChanged | Should -Be 0
        $result.ContentMismatches | Should -Be 0
        $result.BackupPath | Should -BeNullOrEmpty
        foreach ($name in @('empty/', 'empty.xml', 'empty.bin')) {
            $bytes = Read-TestEntry $outputPath $name
            ,$bytes | Should -BeOfType ([byte[]])
            $bytes.Length | Should -Be 0
        }
        [Convert]::ToBase64String((Read-TestEntry $outputPath 'payload.bin')) |
            Should -Be ([Convert]::ToBase64String($binary))
        [Convert]::ToBase64String((Read-TestEntry $outputPath 'content.xml')) |
            Should -Be ([Convert]::ToBase64String($xmlBytes))
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) | Should -Be $sourceBefore
        Assert-NoTemporaryArchive $caseDirectory
    }

    It 'rebuilds a ZIP with no entries without confusing an empty index with null' {
        New-TestArchive $sourcePath @{}
        New-TestArchive $comparePath @{}
        $result = New-SqxProjectArchive $sourcePath $outputPath -CompareProject $comparePath
        $result.EntriesCount | Should -Be 0
        $result.EntriesChanged | Should -Be 0
        $result.ContentMismatches | Should -Be 0
        $archive = [IO.Compression.ZipFile]::OpenRead($outputPath)
        try { $archive.Entries.Count | Should -Be 0 }
        finally { $archive.Dispose() }
        Assert-NoTemporaryArchive $caseDirectory
    }

    It 'treats dollars literally and XML-escapes replacement paths and template overrides' {
        $oldPath = 'C:\old & source\file.sqx'
        $newPath = 'D:\$1\${name}\$&\a & b\"quoted".sqx'
        $template = 'E:\$1\${task}\$&\a & b\<tag>\''quote''\"template".sqx'
        $oldXml = '<task templateFile="old.sqx" output="C:\old &amp; source\file.sqx" />'
        New-TestArchive $sourcePath @{ 'task.xml' = $latin1.GetBytes($oldXml); 'payload.bin' = $binary }

        $result = New-SqxProjectArchive -SourceProject $sourcePath -OutputProject $outputPath `
            -Replacements @{ $oldPath = $newPath } -TaskFile 'task.xml' -TemplateFile $template

        $result.EntriesChanged | Should -Be 1
        $text = $latin1.GetString((Read-TestEntry $outputPath 'task.xml'))
        $expectedText = '<task templateFile="' + [Security.SecurityElement]::Escape($template) +
            '" output="' + [Security.SecurityElement]::Escape($newPath) + '" />'
        $text | Should -BeExactly $expectedText
        $parsed = [xml]$text
        $parsed.task.templateFile | Should -BeExactly $template
        $parsed.task.output | Should -BeExactly $newPath
        [Convert]::ToBase64String((Read-TestEntry $outputPath 'payload.bin')) |
            Should -Be ([Convert]::ToBase64String($binary))
    }

    It 'recognizes case-only XML changes and preserves single-quoted template attributes' {
        New-TestArchive $sourcePath @{ 'task.xml' = $latin1.GetBytes("<task templateFile='old' output='ABC' />") }
        $result = New-SqxProjectArchive -SourceProject $sourcePath -OutputProject $outputPath `
            -Replacements @{ ABC = 'abc' } -TaskFile task.xml -TemplateFile 'D:\$1 & new.sqx'
        $result.EntriesChanged | Should -Be 1
        $text = $latin1.GetString((Read-TestEntry $outputPath 'task.xml'))
        $text | Should -BeExactly '<task templateFile=''D:\$1 &amp; new.sqx'' output=''abc'' />'
    }

    It 'rejects source/output path equality including case-insensitive aliases' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        $before = [IO.File]::ReadAllBytes($sourcePath)
        { New-SqxProjectArchive $sourcePath $sourcePath -Force } | Should -Throw '*distinct files*'
        { New-SqxProjectArchive $sourcePath $sourcePath.ToUpperInvariant() -Force } | Should -Throw '*distinct files*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) |
            Should -Be ([Convert]::ToBase64String($before))
    }

    It 'rejects compare aliases of either source or output' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        New-TestArchive $outputPath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        { New-SqxProjectArchive $sourcePath $outputPath -CompareProject $sourcePath -Force } |
            Should -Throw '*distinct files*'
        { New-SqxProjectArchive $sourcePath $outputPath -CompareProject $outputPath -Force } |
            Should -Throw '*distinct files*'
        Assert-NoTemporaryArchive $caseDirectory
    }

    It 'rejects Windows hard-link aliases without touching source' -Skip:($env:OS -ne 'Windows_NT') {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        $null = New-Item -ItemType HardLink -Path $outputPath -Target $sourcePath
        { New-SqxProjectArchive $sourcePath $outputPath -Force } | Should -Throw '*same file alias*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) |
            Should -Be ([Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)))
    }

    It 'does not create output, backups or temporary files under WhatIf' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        $result = New-SqxProjectArchive $sourcePath $outputPath -WhatIf
        $result | Should -BeNullOrEmpty
        Test-Path -LiteralPath $outputPath | Should -BeFalse
        Assert-NoTemporaryArchive $caseDirectory
        @(Get-ChildItem -LiteralPath $caseDirectory -Force).Count | Should -Be 1
    }

    It 'requires Force to overwrite and preserves the exact prior output in a unique backup' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        [IO.File]::WriteAllBytes($outputPath, $binary)
        { New-SqxProjectArchive $sourcePath $outputPath } | Should -Throw '*-Force*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) |
            Should -Be ([Convert]::ToBase64String($binary))
        New-SqxProjectArchive $sourcePath $outputPath -Force -WhatIf
        @(Get-ChildItem -LiteralPath $caseDirectory -Filter '*.bak' -Force).Count | Should -Be 0

        $result = New-SqxProjectArchive $sourcePath $outputPath -Force
        Test-Path -LiteralPath $result.BackupPath | Should -BeTrue
        [IO.Path]::GetDirectoryName($result.BackupPath) | Should -Be $caseDirectory
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.BackupPath)) |
            Should -Be ([Convert]::ToBase64String($binary))
        $secondResult = New-SqxProjectArchive $sourcePath $outputPath -Force
        $secondResult.BackupPath | Should -Not -Be $result.BackupPath
        Test-Path -LiteralPath $result.BackupPath | Should -BeTrue
        Assert-NoTemporaryArchive $caseDirectory
    }

    It 'preserves existing output and leaves no temporary or backup on an invalid source' {
        [IO.File]::WriteAllText($sourcePath, 'not a ZIP')
        [IO.File]::WriteAllBytes($outputPath, $binary)
        { New-SqxProjectArchive $sourcePath $outputPath -Force } | Should -Throw
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) |
            Should -Be ([Convert]::ToBase64String($binary))
        Assert-NoTemporaryArchive $caseDirectory
        @(Get-ChildItem -LiteralPath $caseDirectory -Force -Filter '*.bak').Count | Should -Be 0
        # Resource disposal is observable: all fixtures can be exclusively opened.
        foreach ($path in @($sourcePath, $outputPath)) {
            $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
            $stream.Dispose()
        }
    }

    It 'accepts a comparison containing exactly the expected transformed XML and binary bytes' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root path="old" />'); 'data.bin' = $binary; 'empty/' = [byte[]]@() }
        New-TestArchive $comparePath @{ 'a.xml' = $latin1.GetBytes('<root path="new" />'); 'data.bin' = $binary; 'empty/' = [byte[]]@() }
        $result = New-SqxProjectArchive $sourcePath $outputPath -Replacements @{ old = 'new' } -CompareProject $comparePath
        $result.ContentMismatches | Should -Be 0
        $result.EntriesChanged | Should -Be 1
        $result.EntriesCount | Should -Be 3
    }

    It 'fails validation before publishing for <Kind> comparison differences' -ForEach @(
        @{ Kind = 'missing' }
        @{ Kind = 'extra' }
        @{ Kind = 'binary' }
        @{ Kind = 'untransformed XML' }
        @{ Kind = 'case-sensitive entry name' }
    ) {
        $sourceEntries = @{ 'a.xml' = $latin1.GetBytes('<root path="old" />'); 'data.bin' = $binary }
        $expectedEntries = @{ 'a.xml' = $latin1.GetBytes('<root path="new" />'); 'data.bin' = $binary }
        switch ($Kind) {
            'missing' { $expectedEntries['expected.bin'] = [byte[]]@() }
            'extra' { $expectedEntries.Remove('data.bin') }
            'binary' { $expectedEntries['data.bin'] = [byte[]](1, 2, 3) }
            'untransformed XML' { $expectedEntries['a.xml'] = $sourceEntries['a.xml'] }
            'case-sensitive entry name' {
                $expectedEntries.Remove('data.bin')
                $expectedEntries['DATA.bin'] = $binary
            }
        }
        New-TestArchive $sourcePath $sourceEntries
        New-TestArchive $comparePath $expectedEntries
        [IO.File]::WriteAllBytes($outputPath, $binary)
        { New-SqxProjectArchive $sourcePath $outputPath -Replacements @{ old = 'new' } -CompareProject $comparePath -Force } |
            Should -Throw '*comparison validation failed*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) |
            Should -Be ([Convert]::ToBase64String($binary))
        Assert-NoTemporaryArchive $caseDirectory
        @(Get-ChildItem -LiteralPath $caseDirectory -Force -Filter '*.bak').Count | Should -Be 0
        foreach ($path in @($sourcePath, $comparePath, $outputPath)) {
            $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
            $stream.Dispose()
        }
    }

    It 'cleans a partly built temporary ZIP after a transformation failure' {
        New-TestArchive $sourcePath ([ordered]@{
            'already-written.bin' = $binary
            'task.xml' = $latin1.GetBytes('<task templateFile="old" />')
        })
        [IO.File]::WriteAllBytes($outputPath, $binary)
        $unrepresentablePath = 'C:\' + [char]0x4E2D + '\template.sqx'
        { New-SqxProjectArchive $sourcePath $outputPath -TaskFile task.xml -TemplateFile $unrepresentablePath -Force } |
            Should -Throw
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) |
            Should -Be ([Convert]::ToBase64String($binary))
        Assert-NoTemporaryArchive $caseDirectory
        @(Get-ChildItem -LiteralPath $caseDirectory -Force -Filter '*.bak').Count | Should -Be 0
    }

    It 'rejects a non-ASCII <Component> before changing existing output' -ForEach @(
        @{ Component = 'replacement key' }
        @{ Component = 'replacement value' }
        @{ Component = 'template path' }
    ) {
        $oldPath = 'C:\old.sqx'
        $newPath = 'D:\new.sqx'
        $templatePath = 'D:\template.sqx'
        switch ($Component) {
            'replacement key' { $oldPath = 'C:\' + [char]0x6A21 + '\old.sqx' }
            'replacement value' { $newPath = 'D:\caf' + [char]0xE9 + '\new.sqx' }
            'template path' { $templatePath = 'D:\' + [char]0x6A21 + '\caf' + [char]0xE9 + '.sqx' }
        }
        $xml = '<task templateFile="old.sqx" output="' + $oldPath + '" />'
        New-TestArchive $sourcePath @{ 'task.xml' = [Text.Encoding]::UTF8.GetBytes($xml); 'payload.bin' = $binary }
        New-TestArchive $outputPath @{ 'original.bin' = $binary }
        $sourceBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath))
        $outputBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath))

        { New-SqxProjectArchive $sourcePath $outputPath -Replacements @{ $oldPath = $newPath } `
                -TaskFile task.xml -TemplateFile $templatePath -Force } | Should -Throw '*ASCII*'

        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) | Should -BeExactly $outputBefore
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) | Should -BeExactly $sourceBefore
        Assert-NoTemporaryArchive $caseDirectory
        @(Get-ChildItem -LiteralPath $caseDirectory -Force -Filter '*.bak').Count | Should -Be 0
    }

    It 'invokes the compatibility entry point only against a safe fixture and forwards WhatIf' {
        $entryPoint = Join-Path $PSScriptRoot '../../scripts/sqx/Rebuild-SqxProject.ps1'
        $oldBase = 'C:\old-base'
        $xml = '<task templateFile="C:\old-base\S001_entry_revised_template.sqx" output="C:\old-base\S001_sys_parameters" install="C:\SQX144\user" />'
        New-TestArchive $sourcePath @{ 'task.xml' = $latin1.GetBytes($xml); 'payload.bin' = $binary }
        $arguments = @{
            SourceProject = $sourcePath
            OutputProject = $outputPath
            OldBase = $oldBase
            OldInstallBase = 'C:\SQX144'
            NewInstallBase = 'D:\SQX145'
        }
        # Invoke the script, never dot-source it into the Pester scope.
        & $entryPoint @arguments -WhatIf
        Test-Path -LiteralPath $outputPath | Should -BeFalse
        $result = & $entryPoint @arguments
        $result.EntriesChanged | Should -Be 1
        $text = $latin1.GetString((Read-TestEntry $outputPath 'task.xml'))
        $text | Should -BeExactly '<task templateFile="C:\StrategyQuantX145\user\settings\StrategyTemplates\S001_entry_revised_template.sqx" output="C:\StrategyQuantX145\user\S001_sys_parameters" install="D:\SQX145\user" />'
        Assert-NoTemporaryArchive $caseDirectory
    }

    It 'rejects missing task XML and unpaired task parameters rather than silently succeeding' {
        New-TestArchive $sourcePath @{ 'a.xml' = $latin1.GetBytes('<root />') }
        { New-SqxProjectArchive $sourcePath $outputPath -TaskFile missing.xml } | Should -Throw '*supplied together*'
        { New-SqxProjectArchive $sourcePath $outputPath -TaskFile missing.xml -TemplateFile template.sqx } |
            Should -Throw '*not found*'
        Test-Path -LiteralPath $outputPath | Should -BeFalse
        Assert-NoTemporaryArchive $caseDirectory
    }
}
