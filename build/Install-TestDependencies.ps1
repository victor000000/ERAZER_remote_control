#requires -Version 5.1
<#
.SYNOPSIS
Explicitly downloads repository-local, pinned test tooling from PSGallery.
.DESCRIPTION
Run this once before Invoke-Checks.ps1. Nothing is installed into user/system
module directories, and no repository trust, profile, or persistent setting is
changed. This is the only build step that needs network access.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$dependencyRoot = Join-Path $repositoryRoot 'out/dependencies'
$dependencies = @(
    @{ Name = 'Pester'; Version = '5.7.1' }
    @{ Name = 'PSScriptAnalyzer'; Version = '1.24.0' }
)
$originalSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol

try {
    if (-not (Get-Command Save-Module -ErrorAction SilentlyContinue)) {
        throw 'Save-Module is required. Use a PowerShell environment with PowerShellGet available; this script does not install global package providers.'
    }
    # Windows PowerShell 5.1 may otherwise negotiate an obsolete TLS version.
    # This setting is process-local and is restored even if the download fails.
    [Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Path $dependencyRoot -Force | Out-Null

    foreach ($dependency in $dependencies) {
        $manifestPath = Join-Path $dependencyRoot ('{0}/{1}/{0}.psd1' -f $dependency.Name, $dependency.Version)
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
            if ([string]$manifest.ModuleVersion -eq $dependency.Version) {
                Write-Host ('Already saved: {0} {1}' -f $dependency.Name, $dependency.Version)
                continue
            }
            throw ('Unexpected module version in {0}. Remove that dependency directory and run this bootstrap again.' -f $manifestPath)
        }

        # Do not let PowerShellGet silently bootstrap a persistent NuGet provider.
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            throw 'An existing NuGet package provider is required by Save-Module. Run this bootstrap with PowerShell 7 (pwsh); no provider will be installed globally.'
        }
        Write-Host ('Saving {0} {1} into out/dependencies.' -f $dependency.Name, $dependency.Version)
        Save-Module -Name $dependency.Name -RequiredVersion $dependency.Version -Repository PSGallery -Path $dependencyRoot -Force -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw ('Save-Module did not create the expected {0} {1} manifest.' -f $dependency.Name, $dependency.Version)
        }
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        if ([string]$manifest.ModuleVersion -ne $dependency.Version) {
            throw ('The saved {0} manifest does not match pinned version {1}.' -f $dependency.Name, $dependency.Version)
        }
    }
    Write-Host 'Test dependencies are ready. Run build/Invoke-Checks.ps1 for offline checks.'
}
catch {
    Write-Error -Message ('Dependency bootstrap failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
    exit 1
}
finally {
    [Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
}
