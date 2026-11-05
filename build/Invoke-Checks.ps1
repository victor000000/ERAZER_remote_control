#requires -Version 5.1
<#
.SYNOPSIS
Runs offline syntax, safety lint, and Pester checks using pinned local tooling.
.DESCRIPTION
Does not download dependencies or contact either PC. Run
build/Install-TestDependencies.ps1 explicitly beforehand. Output is isolated by
shell under out/test-results/powershell or out/test-results/pwsh.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$shellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$resultRoot = Join-Path $repositoryRoot ('out/test-results/{0}' -f $shellName)
$failed = $false

try {
    New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null
    foreach ($artifactName in @('parse-errors.txt', 'script-analyzer.txt', 'tests.nunit.xml', 'coverage.xml')) {
        $artifactPath = Join-Path $resultRoot $artifactName
        if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
            Remove-Item -LiteralPath $artifactPath -Force
        }
    }
    $dependencies = @(
        @{ Name = 'Pester'; Version = '5.7.1' }
        @{ Name = 'PSScriptAnalyzer'; Version = '1.24.0' }
    )
    foreach ($dependency in $dependencies) {
        $manifestPath = Join-Path $repositoryRoot ('out/dependencies/{0}/{1}/{0}.psd1' -f $dependency.Name, $dependency.Version)
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw ('Missing pinned dependency {0} {1}. Run build/Install-TestDependencies.ps1 explicitly (prefer pwsh), then rerun checks.' -f $dependency.Name, $dependency.Version)
        }
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        if ([string]$manifest.ModuleVersion -ne $dependency.Version) {
            throw ('Pinned dependency version mismatch: {0} must be {1}. Rerun the explicit dependency bootstrap.' -f $dependency.Name, $dependency.Version)
        }
        # Never resolve a globally installed, possibly different module version.
        Remove-Module -Name $dependency.Name -Force -ErrorAction SilentlyContinue
        $imported = Import-Module -Name $manifestPath -Force -PassThru -ErrorAction Stop
        if ([string]$imported.Version -ne $dependency.Version) {
            throw ('Loaded an unexpected version of {0}.' -f $dependency.Name)
        }
    }

    # Include tracked archive scripts, as well as new files during a refactor.
    # Deleted tracked paths are normal in an unstaged rename and are not parsed.
    # No uncontrolled recursive enumeration of logs, caches or dependency trees.
    $gitOutput = @(& git -C $repositoryRoot ls-files --cached --others --exclude-standard -z -- '*.ps1' '*.psm1' '*.psd1')
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed; run checks inside a Git checkout.' }
    $relativeFiles = @((($gitOutput -join "`n").Split([char[]]@([char]0), [StringSplitOptions]::RemoveEmptyEntries)) |
        Where-Object { $_ -notmatch '^(?:out|\.git)/' } |
        Sort-Object -Unique |
        Where-Object { Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf })
    if ($relativeFiles.Count -eq 0) { throw 'No repository PowerShell files were found to check.' }

    Write-Host ('Parsing {0} PowerShell files, including archive (PowerShell {1}).' -f $relativeFiles.Count, $PSVersionTable.PSVersion)
    $parseDiagnostics = @(
        foreach ($relativePath in $relativeFiles) {
            $parseTokens = $null
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryRoot $relativePath), [ref]$parseTokens, [ref]$parseErrors)
            foreach ($parseError in $parseErrors) {
                '{0}:{1}: {2}: {3}' -f $relativePath, $parseError.Extent.StartLineNumber, $parseError.ErrorId, $parseError.Message
            }
        }
    )
    [IO.File]::WriteAllLines((Join-Path $resultRoot 'parse-errors.txt'), [string[]]$parseDiagnostics)
    foreach ($diagnostic in $parseDiagnostics) { Write-Host $diagnostic }
    if ($parseDiagnostics.Count -gt 0) { $failed = $true }

    $maintainedFiles = @($relativeFiles | Where-Object { $_ -match '^(?:src|scripts|build|tools)/' })
    Write-Host ('Safety lint: {0} maintained files (archive excluded).' -f $maintainedFiles.Count)
    $lintDiagnostics = @(
        foreach ($relativePath in $maintainedFiles) {
            try {
                $diagnostics = @(Invoke-ScriptAnalyzer -Path (Join-Path $repositoryRoot $relativePath) -Settings (Join-Path $repositoryRoot 'tests/ScriptAnalyzerSettings.psd1') -ErrorAction Stop)
                foreach ($diagnostic in $diagnostics) {
                    '{0}:{1}: {2}: {3}' -f $relativePath, $diagnostic.Line, $diagnostic.RuleName, $diagnostic.Message
                }
            }
            catch {
                '{0}: analyzer failed: {1}' -f $relativePath, $_.Exception.Message
            }
        }
    )
    [IO.File]::WriteAllLines((Join-Path $resultRoot 'script-analyzer.txt'), [string[]]$lintDiagnostics)
    foreach ($diagnostic in $lintDiagnostics) { Write-Host $diagnostic }
    if ($lintDiagnostics.Count -gt 0) { $failed = $true }

    $coveragePaths = @($relativeFiles |
        Where-Object { $_ -match '^src/.+\.(?:ps1|psm1)$' } |
        ForEach-Object { Join-Path $repositoryRoot $_ })
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = @(Join-Path $repositoryRoot 'tests')
    $configuration.Run.PassThru = $true
    $configuration.Run.Exit = $false
    $configuration.Output.Verbosity = 'Detailed'
    $configuration.Output.StackTraceVerbosity = 'FirstLine'
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = Join-Path $resultRoot 'tests.nunit.xml'
    $configuration.CodeCoverage.Enabled = $coveragePaths.Count -gt 0
    $configuration.CodeCoverage.Path = $coveragePaths
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $resultRoot 'coverage.xml'
    # Pester reports the target but does not itself make unmet coverage fatal.
    $configuration.CodeCoverage.CoveragePercentTarget = 90

    $testResult = Invoke-Pester -Configuration $configuration
    if ($null -eq $testResult -or $testResult.Result -ne 'Passed' -or $testResult.TotalCount -eq 0) {
        $failed = $true
    }
    . (Join-Path $PSScriptRoot 'Assert-ModuleCoverage.ps1')
    Assert-ModuleCoverage -Coverage $testResult.CodeCoverage -MinimumPercent $configuration.CodeCoverage.CoveragePercentTarget.Value
    Write-Host ('Check artifacts: {0}' -f $resultRoot)
    if ($failed) {
        Write-Error -Message 'Repository checks failed. See the diagnostics and NUnit results above.' -ErrorAction Continue
        exit 1
    }
    Write-Host 'All repository checks passed.'
    exit 0
}
catch {
    Write-Error -Message ('Repository checks failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
    exit 1
}
