#requires -Version 5.1
# Definition-only build helper, shared by the runner and offline regression tests.
function Assert-ModuleCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Coverage,
        [ValidateRange(0, 100)][double]$MinimumPercent = 90
    )

    if ($null -eq $Coverage -or $null -eq $Coverage.CoveragePercent -or $Coverage.CommandsAnalyzedCount -le 0) {
        throw 'Module command coverage is missing or contains no analyzed commands.'
    }
    $percent = [double]$Coverage.CoveragePercent
    if ([double]::IsNaN($percent) -or $percent -lt 0 -or $percent -gt 100) {
        throw 'Module command coverage is not a valid percentage.'
    }
    if ($percent -lt $MinimumPercent) {
        throw ('Module command coverage {0:N2}% is below the required {1:N2}%.' -f $percent, $MinimumPercent)
    }
}
