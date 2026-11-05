$ProgressPreference = 'SilentlyContinue'
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if (-not $p) { Write-Output 'NO_SQCLI'; return }
$before = $p.PriorityClass
try {
    $p.PriorityClass = 'High'
    $setResult = 'ok'
} catch {
    $setResult = 'FAILED: ' + $_.Exception.Message
}
Start-Sleep -Seconds 2
$after = (Get-Process -Id $p.Id -ErrorAction SilentlyContinue).PriorityClass
Write-Output ("before={0} after={1} set={2}" -f $before, $after, $setResult)
