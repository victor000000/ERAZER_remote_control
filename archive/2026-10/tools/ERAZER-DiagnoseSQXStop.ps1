$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('now=' + (Get-Date))
W ('ComputerUser=' + (Get-CimInstance Win32_ComputerSystem).UserName)
W ('RAM free MB=' + [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1KB))

W '--- PROCESSES ---'
Get-Process sqcli, StrategyQuantX, pwsh, java -ErrorAction SilentlyContinue |
    Select-Object Name, Id, SessionId, StartTime, @{n='WSMB';e={[math]::Round($_.WorkingSet64/1MB)}} |
    Format-Table -AutoSize | Out-String | Write-Output

W '--- TASK ---'
$t = Get-ScheduledTask -TaskName 'SQX-Task1-Headless' -ErrorAction SilentlyContinue
if ($t) {
    W ('state=' + $t.State + ' user=' + $t.Principal.UserId + ' logon=' + $t.Principal.LogonType)
    Get-ScheduledTaskInfo -TaskName 'SQX-Task1-Headless' | Select-Object LastRunTime, LastTaskResult, NextRunTime | Format-List | Out-String | Write-Output
} else { W 'task missing' }

W '--- ENGINE LOG TAIL ---'
$el = Get-ChildItem 'C:\StrategyQuantX145\user\log\StrategyQuant' -Filter 'log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($el) {
    W ('file=' + $el.Name + ' modified=' + $el.LastWriteTime)
    Get-Content $el.FullName -Tail 25 | ForEach-Object { W ('  ' + $_.Substring(0, [Math]::Min(220, $_.Length))) }
}

W '--- PROJECT LOG TAIL ---'
$pl = Get-ChildItem 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\log' -Filter 'global_log_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($pl) {
    W ('file=' + $pl.Name + ' modified=' + $pl.LastWriteTime)
    Get-Content $pl.FullName -Tail 10 | ForEach-Object { W ('  ' + $_) }
}

W '--- DATABANK COUNT ---'
$db = 'C:\StrategyQuantX145\user\projects\S001_reproduce_project\databanks\databank1_S001_use_nasdaq100'
W ('  files=' + @(Get-ChildItem $db -File -Filter '*.sqx' -ErrorAction SilentlyContinue).Count + ' newest=' + (Get-ChildItem $db -File -Filter '*.sqx' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime)

W '--- RECENT APPLICATION ERRORS ---'
try {
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddHours(-3); Level = 1, 2 } -ErrorAction Stop |
        Select-Object -First 15 TimeCreated, ProviderName, Id, @{n='Msg';e={($_.Message -replace "`r?`n", ' ').Substring(0, [Math]::Min(160, $_.Message.Length))}} |
        Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Output
} catch { W ('  event query failed: ' + $_.Exception.Message) }
