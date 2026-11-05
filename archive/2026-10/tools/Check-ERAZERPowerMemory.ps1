$ProgressPreference = 'SilentlyContinue'
$os = Get-CimInstance Win32_OperatingSystem
Write-Output ('RAM total MB=' + [math]::Round($os.TotalVisibleMemorySize / 1KB) + ' free MB=' + [math]::Round($os.FreePhysicalMemory / 1KB))
Get-CimInstance Win32_PageFileUsage | ForEach-Object {
    Write-Output ('PageFile allocated MB=' + $_.AllocatedBaseSize + ' peak MB=' + $_.PeakUsage + ' current MB=' + $_.CurrentUsage)
}

$o = powercfg /query SCHEME_CURRENT SUB_PROCESSOR
$names = 'Processor performance boost mode', 'Core parking min cores', 'Minimum processor state', 'Maximum processor state', 'System cooling policy'
for ($i = 0; $i -lt $o.Count; $i++) {
    foreach ($n in $names) {
        if ($o[$i] -match [regex]::Escape($n)) {
            for ($j = $i; $j -lt [Math]::Min($i + 5, $o.Count); $j++) { Write-Output $o[$j] }
            Write-Output ''
        }
    }
}

Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, CPU, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
