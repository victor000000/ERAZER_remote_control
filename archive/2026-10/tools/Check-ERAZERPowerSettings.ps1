$ProgressPreference = 'SilentlyContinue'
$settings = @(
    @('Min processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN'),
    @('Max processor state', 'SUB_PROCESSOR', 'PROCTHROTTLEMAX'),
    @('Boost mode', '54533251-82BE-4824-96C1-47B60B740D00', 'BE337238-0D82-4146-A960-4F3749D470C7'),
    @('Core parking min cores', '54533251-82BE-4824-96C1-47B60B740D00', '0CC5B647-C1DF-4637-891A-DEC359347B2B'),
    @('System cooling policy', '54533251-82BE-4824-96C1-47B60B740D00', '94D3A615-A899-4AC5-AE2B-E4D8F634367F')
)
foreach ($s in $settings) {
    $o = powercfg /query SCHEME_CURRENT $s[1] $s[2] 2>$null
    $ac = ($o | Select-String 'Current AC Power Setting Index').ToString().Trim()
    $dc = ($o | Select-String 'Current DC Power Setting Index').ToString().Trim()
    Write-Output ($s[0] + ': ' + $ac + ' | ' + $dc)
    if (-not $ac) { $o | Select-Object -First 12 | ForEach-Object { Write-Output ('  ' + $_) } }
}
