param(
    [string]$OldInstall = 'C:\StrategyQuantX144',
    [string]$NewInstall = 'C:\StrategyQuantX145',
    [switch]$SkipData
)

$ErrorActionPreference = 'Continue'

if (Get-Process StrategyQuantX -ErrorAction SilentlyContinue) {
    throw 'Close StrategyQuant X before migrating its data.'
}
if (-not (Test-Path -LiteralPath $OldInstall)) {
    throw "Old install not found: $OldInstall"
}
if (-not (Test-Path -LiteralPath $NewInstall)) {
    throw "New install not found: $NewInstall"
}

$folders = @('projects', 'settings', 'extend', 'customdata', 'strategies', 'S001_sys_parameters')
if (-not $SkipData) { $folders += 'data' }

foreach ($folder in $folders) {
    $src = Join-Path $OldInstall "user\$folder"
    $dst = Join-Path $NewInstall "user\$folder"
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Output "skip (missing): $folder"
        continue
    }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    robocopy $src $dst /E /J /MT:8 /R:1 /W:1 /NFL /NDL /NP | Out-Null
    $code = $LASTEXITCODE
    if ($code -le 7) {
        Write-Output "copied: $folder (robocopy exit $code)"
    } else {
        Write-Output "FAILED: $folder (robocopy exit $code)"
    }
}

foreach ($folder in @('custom_indicators', 'VolumeProfile')) {
    $src = Join-Path $OldInstall $folder
    $dst = Join-Path $NewInstall $folder
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Output "skip (missing): $folder"
        continue
    }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    robocopy $src $dst /E /J /MT:8 /R:1 /W:1 /NFL /NDL /NP | Out-Null
    $code = $LASTEXITCODE
    if ($code -le 7) {
        Write-Output "copied: $folder (robocopy exit $code)"
    } else {
        Write-Output "FAILED: $folder (robocopy exit $code)"
    }
}

Write-Output 'Data migration finished. Merge the launcher configs and patch the project paths next.'
