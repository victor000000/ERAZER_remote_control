# Repository-only checks. Never dot-source entry scripts or execute archive/.
BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot

    function Get-RepositoryFile {
        param(
            [switch]$IncludeUntracked,
            [string]$Root = $repositoryRoot
        )
        $gitArguments = @('-C', $Root, 'ls-files', '--cached', '-z')
        if ($IncludeUntracked) { $gitArguments += @('--others', '--exclude-standard') }
        $gitOutput = @(& git @gitArguments)
        if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed for repository safety checks.' }
        @(($gitOutput -join "`n").Split([char[]]@([char]0), [StringSplitOptions]::RemoveEmptyEntries) | Sort-Object -Unique)
    }

    function Resolve-RepositorySource {
        param([Parameter(Mandatory)][string]$RelativePath)
        if ([IO.Path]::IsPathRooted($RelativePath) -or
            $RelativePath -match '[:*?]' -or
            $RelativePath -match '(?:^|[/\\])\.\.(?:[/\\]|$)') {
            throw 'Source must be a plain relative file path without traversal.'
        }
        $rootPrefix = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd([char[]]@('/', '\')) + [IO.Path]::DirectorySeparatorChar
        $fullPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
        if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Source must stay inside the repository root.'
        }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw ('Missing repository source: {0}' -f $RelativePath)
        }
        # A lexical root check alone would allow a symlink/junction to escape.
        $entry = Get-Item -LiteralPath $fullPath -Force
        while ($null -ne $entry -and $entry.FullName.TrimEnd([char[]]@('/', '\')) -ne $repositoryRoot.TrimEnd([char[]]@('/', '\'))) {
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw ('Repository source traverses a reparse point: {0}' -f $RelativePath)
            }
            if ($entry -is [IO.FileInfo]) {
                $entry = $entry.Directory
            }
            else {
                $entry = $entry.Parent
            }
        }
        $fullPath
    }

    function Find-ObviousCredentialLocation {
        param(
            [Parameter(Mandatory)][string]$RelativePath,
            [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines
        )
        # High-confidence prefixes only. No entropy heuristics or password-value
        # guessing. Short/redacted examples such as tskey-auth- are not tokens.
        $patterns = @(
            '(?<![A-Za-z0-9])tskey-(?:auth|api|client)-[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])'
            '(?<![A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{36,}(?![A-Za-z0-9])'
            '(?<![A-Za-z0-9])github_pat_[A-Za-z0-9_]{60,}(?![A-Za-z0-9_])'
            '(?<![A-Za-z0-9])glpat-[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])'
            '(?<![A-Za-z0-9])sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{40,}(?![A-Za-z0-9_-])'
            '(?<![A-Za-z0-9])sk-(?:proj-)?[A-Za-z0-9_-]{40,}(?![A-Za-z0-9_-])'
            '(?<![A-Z0-9])AKIA[A-Z0-9]{16}(?![A-Z0-9])'
            '-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'
        )
        for ($lineIndex = 0; $lineIndex -lt $Lines.Count; $lineIndex++) {
            foreach ($pattern in $patterns) {
                if ([regex]::IsMatch($Lines[$lineIndex], $pattern)) {
                    # Deliberately never return a Match, source line, or value.
                    [pscustomobject]@{ Path = $RelativePath; Line = $lineIndex + 1 }
                    break
                }
            }
        }
    }

    $trackedFiles = @(Get-RepositoryFile)
    $candidateFiles = @(Get-RepositoryFile -IncludeUntracked)
    . (Join-Path $repositoryRoot 'build/Assert-ModuleCoverage.ps1')
}

Describe 'Supported repository entry points' {
    It 'preserves the root connector' {
        Test-Path -LiteralPath (Join-Path $repositoryRoot 'Connect-ERAZER.ps1') -PathType Leaf | Should -BeTrue
    }

    It 'points every supported PowerShell shim at an existing canonical script' {
        $shims = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'tools') -Filter '*.ps1' -File)
        $shims.Count | Should -BeGreaterThan 0
        foreach ($shim in $shims) {
            $parseTokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($shim.FullName, [ref]$parseTokens, [ref]$parseErrors)
            @($parseErrors).Count | Should -Be 0 -Because ('shim {0} must parse' -f $shim.Name)
            $targets = @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                    $node.Value -match '^(?:\.\.[/\\])?scripts[/\\].+\.ps1$'
            }, $true) | ForEach-Object { $_.Value })
            $targets.Count | Should -BeGreaterThan 0 -Because ('shim {0} must identify its canonical scripts/ target with a literal relative path' -f $shim.Name)
            foreach ($target in $targets) {
                # Shims may join from the repository root or from tools/.
                $canonicalRelativePath = $target -replace '^\.\.[/\\]', ''
                { Resolve-RepositorySource -RelativePath $canonicalRelativePath } | Should -Not -Throw
            }
        }
    }
}

Describe 'Module manifest and deployment contract' {
    It 'has an importable manifest with exactly the declared function exports' {
        $manifestPath = Join-Path $repositoryRoot 'src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
        $manifestData = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
        $declared = @($manifestData.FunctionsToExport | Sort-Object)
        $declared.Count | Should -BeGreaterThan 0
        @($declared | Where-Object { $_ -match '[*?]' }).Count | Should -Be 0
        # Module import is the sole production code loaded by these checks. Its
        # contract is definition-only; no entry script or host operation is run.
        $module = Import-Module -Name $manifestPath -Force -PassThru -ErrorAction Stop
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        @((Compare-Object -ReferenceObject $declared -DifferenceObject $actual)).Count | Should -Be 0
        foreach ($functionName in $declared) {
            $module.ExportedFunctions.ContainsKey($functionName) | Should -BeTrue
        }
    }

    It 'lists only existing in-repository deployment source files' {
        $deployment = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config/deployment.psd1') -ErrorAction Stop
        $deployment.ContainsKey('Files') | Should -BeTrue
        $deployment.Files.Count | Should -BeGreaterThan 0
        foreach ($source in $deployment.Files) {
            ($source -is [string]) | Should -BeTrue -Because 'deployment Files is an array of relative file strings'
            [string]::IsNullOrWhiteSpace($source) | Should -BeFalse
            { Resolve-RepositorySource -RelativePath $source } | Should -Not -Throw
        }
        @($deployment.Files | Sort-Object -Unique).Count | Should -Be $deployment.Files.Count
    }

    It 'rejects absolute, traversal and alternate-stream source paths' {
        foreach ($invalidSource in @('../outside.ps1', 'src/../../outside.ps1', 'C:\outside.ps1', '\\server\share\outside.ps1', 'src/file.ps1:stream')) {
            { Resolve-RepositorySource -RelativePath $invalidSource } | Should -Throw
        }
    }
}

Describe 'Runtime outputs and local credentials' {
    It 'does not track runtime directories or local credential files' {
        $unexpected = @($trackedFiles | Where-Object {
            $_ -match '^(?:out|reports?|logs?|backups?|cache|\.cache|dependencies|deps|test-results|TestResults)/' -or
            $_ -match '(?:^|/)(?:credentials\.local\.txt|local\.psd1)$' -or
            $_ -match '\.local\.' -or
            ($_ -notmatch '^tests/fixtures/' -and $_ -match '\.(?:log|bak|pyc|trx)$')
        })
        $unexpected.Count | Should -Be 0 -Because ('runtime/local files must be untracked: {0}' -f ($unexpected -join ', '))
    }

    It 'ignores local configuration and generated dependency/test output paths' {
        foreach ($relativePath in @('credentials.local.txt', 'config/local.psd1', 'config/example.local.psd1', 'out/dependencies/example.psd1', 'out/test-results/pwsh/tests.nunit.xml', 'logs/run.log', 'backups/example.bak', 'cache/example.tmp')) {
            & git -C $repositoryRoot check-ignore --no-index -q -- $relativePath
            $LASTEXITCODE | Should -Be 0 -Because ('{0} must be ignored' -f $relativePath)
        }
    }

    It 'does not blanket-ignore fixture data or module source files' {
        foreach ($relativePath in @('tests/fixtures/example.json', 'tests/fixtures/example.xml', 'tests/fixtures/example.png', 'src/ERAZER.RemoteControl/Example.ps1', 'src/ERAZER.RemoteControl/Example.psm1', 'src/ERAZER.RemoteControl/Example.psd1')) {
            & git -C $repositoryRoot check-ignore --no-index -q -- $relativePath
            $LASTEXITCODE | Should -Be 1 -Because ('{0} must remain eligible for version control' -f $relativePath)
        }
    }
}

Describe 'High-confidence candidate-file credential scan' {
    It 'reports only file and line locations for obvious credentials' {
        $locations = @(
            foreach ($relativePath in $candidateFiles) {
                $fullPath = Join-Path $repositoryRoot $relativePath
                # Deleted index entries can remain while a rename is unstaged.
                if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
                $lines = [IO.File]::ReadAllLines($fullPath)
                Find-ObviousCredentialLocation -RelativePath $relativePath -Lines $lines
            }
        )
        $safeReport = @($locations | ForEach-Object { '{0}:{1}' -f $_.Path, $_.Line }) -join ', '
        $locations.Count | Should -Be 0 -Because ('possible tracked or new nonignored credentials (path:line only): {0}' -f $safeReport)
    }

    It 'accepts short prefixes and documented redacted placeholders' {
        $placeholderLines = @('tskey-auth-', 'tskey-auth-<redacted>', 'tskey-api-REDACTED', 'tskey-client-', 'tskey-client-<redacted>', 'ghp_<redacted>', 'sk-ant-api03-<redacted>')
        @(Find-ObviousCredentialLocation -RelativePath 'fixture.txt' -Lines $placeholderLines).Count | Should -Be 0
    }

    It 'includes untracked nonignored files without enumerating ignored runtime output' {
        $fixtureRoot = Join-Path $TestDrive 'candidate-repository'
        New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
        & git -C $fixtureRoot init -q
        $LASTEXITCODE | Should -Be 0
        Set-Content -LiteralPath (Join-Path $fixtureRoot '.gitignore') -Value 'out/'
        $newFilePath = Join-Path $fixtureRoot 'new-source.txt'
        Set-Content -LiteralPath $newFilePath -Value ('tskey-' + 'client-' + ('a' * 40))
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'out') | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'out/ignored.txt') -Value 'ignored fixture output'

        @(Get-RepositoryFile -Root $fixtureRoot).Count | Should -Be 0
        $candidates = @(Get-RepositoryFile -Root $fixtureRoot -IncludeUntracked)
        $candidates | Should -Contain 'new-source.txt'
        $candidates | Should -Not -Contain 'out/ignored.txt'
        $locations = @(Find-ObviousCredentialLocation -RelativePath 'new-source.txt' -Lines ([IO.File]::ReadAllLines($newFilePath)))
        $locations.Count | Should -Be 1
        $locations[0].Path | Should -Be 'new-source.txt'
        $locations[0].Line | Should -Be 1
    }

    It 'detects synthetic token and private-key fixtures without returning values' {
        $syntheticLines = @('harmless', ('tskey-auth-' + ('a' * 40)), ('-----BEGIN ' + 'OPENSSH PRIVATE KEY-----'), ('tskey-' + 'client-' + ('a' * 40)))
        $locations = @(Find-ObviousCredentialLocation -RelativePath 'fixture.txt' -Lines $syntheticLines)
        $locations.Count | Should -Be 3
        $locations[0].Path | Should -Be 'fixture.txt'
        $locations[0].Line | Should -Be 2
        $locations[1].Line | Should -Be 3
        $locations[2].Line | Should -Be 4
        @($locations[0].PSObject.Properties.Name | Sort-Object) -join ',' | Should -Be 'Line,Path'
    }
}

Describe 'Build module command coverage gate' {
    It 'rejects a passing test run whose command coverage is below 90 percent' {
        $coverage = [pscustomobject]@{ CoveragePercent = 89.99; CommandsAnalyzedCount = 100 }
        { Assert-ModuleCoverage -Coverage $coverage -MinimumPercent 90 } | Should -Throw '*below the required 90*'
    }

    It 'accepts coverage exactly at or above the configured target' {
        foreach ($percent in @(90, 93.74, 100)) {
            $coverage = [pscustomobject]@{ CoveragePercent = $percent; CommandsAnalyzedCount = 100 }
            { Assert-ModuleCoverage -Coverage $coverage -MinimumPercent 90 } | Should -Not -Throw
        }
    }

    It 'rejects missing or empty coverage instead of silently skipping the gate' {
        foreach ($coverage in @($null, [pscustomobject]@{ CoveragePercent = 100; CommandsAnalyzedCount = 0 })) {
            { Assert-ModuleCoverage -Coverage $coverage -MinimumPercent 90 } | Should -Throw '*missing or contains no analyzed commands*'
        }
    }
}
