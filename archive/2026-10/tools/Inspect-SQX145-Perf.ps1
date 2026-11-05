$ProgressPreference = 'SilentlyContinue'

Write-Output '=== WLAN ==='
netsh wlan show interfaces | Select-String -Pattern 'SSID|Band|Signal|Receive rate|Transmit rate'

Write-Output '=== SQX SETTINGS ==='
Get-Content 'C:\StrategyQuantX145\user\settings\settings.xml' -ErrorAction SilentlyContinue

Write-Output '=== CORE / AI LOG LINES ==='
$log = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Get-Content $log.FullName -Tail 600 |
        Select-String -Pattern 'Adjusting used cores|Using: .*cores|SQAI|High priority|Preparing thread' |
        Select-Object -Last 20 |
        ForEach-Object { $_.Line.Substring(0, [Math]::Min(260, $_.Line.Length)) }
}

Write-Output '=== SQX PROCESS ==='
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, CPU,
        @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB)}},
        @{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB)}} |
    Format-List

Write-Output '=== PROXY WATCH ==='
Get-Content 'C:\Users\Vic\Desktop\proxy-watch.log' -Tail 6 -ErrorAction SilentlyContinue
