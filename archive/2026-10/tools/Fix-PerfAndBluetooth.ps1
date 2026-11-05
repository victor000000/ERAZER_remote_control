$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W ('Perf + Bluetooth fix: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

W '=== BLUETOOTH RE-ENABLE (mouse needs it) ==='
foreach ($n in @('bthserv', 'BTAGService')) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) {
        try {
            Set-Service -Name $n -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $n -ErrorAction Stop
            W ('bluetooth service started: ' + $n)
        } catch {
            try { Set-Service -Name $n -StartupType Manual -ErrorAction SilentlyContinue; Start-Service -Name $n -ErrorAction SilentlyContinue; W ('bluetooth service started (manual): ' + $n) }
            catch { W ('bluetooth service failed ' + $n + ': ' + $_.Exception.Message) }
        }
    }
}
Get-Service -Name 'BluetoothUserService*' -ErrorAction SilentlyContinue | ForEach-Object {
    try { Set-Service -Name $_.Name -StartupType Manual -ErrorAction SilentlyContinue; Start-Service -Name $_.Name -ErrorAction SilentlyContinue; W ('user bluetooth service started: ' + $_.Name) }
    catch { W ('user bluetooth service: ' + $_.Name + ' - ' + $_.Exception.Message) }
}
Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Status -ne 'OK') {
        try { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop; W ('enabled bluetooth device: ' + $_.FriendlyName) }
        catch { W ('bluetooth device enable failed: ' + $_.FriendlyName + ' - ' + $_.Exception.Message) }
    }
}
Get-Service bthserv, BTAGService -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
    Select-Object Status, FriendlyName | Format-Table -AutoSize | Out-String | Write-Output

W '=== TASKbarDa (widgets button) ==='
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
if (-not (Get-ItemProperty -Path $adv -Name TaskbarDa -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $adv -Name TaskbarDa -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
}
Set-ItemProperty -Path $adv -Name TaskbarDa -Value 0 -Type DWord -ErrorAction SilentlyContinue
Get-ItemProperty -Path $adv -Name TaskbarDa -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Output

W '=== SQX FULL HEAP: 28 GB + Xms28g + AlwaysPreTouch ==='
foreach ($f in @('C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config')) {
    if (Test-Path $f) {
        Copy-Item $f ($f + '.bak-full-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
        $c = Get-Content $f -Raw
        $c = $c -replace 'option -Xms4g', 'option -Xms28g'
        $c = $c -replace 'option -Xmx24g', 'option -Xmx28g'
        if ($c -notmatch 'AlwaysPreTouch') {
            $c = $c -replace '(?m)^(option -XX:\+UseParallelGC.*)$', '$1' + "`r`noption -XX:+AlwaysPreTouch"
        }
        Set-Content -Path $f -Value $c -Encoding ASCII
        W ('updated full-use heap: ' + $f)
    }
}
Select-String -Path 'C:\StrategyQuantX145\sqcli.config', 'C:\StrategyQuantX145\StrategyQuantX.config' -Pattern 'Xm[sx]|AlwaysPreTouch|UseParallelGC' |
    ForEach-Object { W ($_.Path + ': ' + $_.Line.Trim()) }

W '=== CURRENT ENGINE ==='
Get-Process sqcli -ErrorAction SilentlyContinue |
    Select-Object Id, PriorityClass, @{n='WSMB';e={[math]::Round($_.WorkingSet64 / 1MB)}} |
    Format-List | Out-String | Write-Output
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State | Write-Output
