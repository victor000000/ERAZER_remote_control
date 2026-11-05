$out = 'C:\Users\victo\ERAZER_remote_control\mwb-restart-local.txt'
function Log([string]$m) { "$(Get-Date -Format o) $m" | Add-Content -Path $out -Encoding UTF8 }
Set-Content -Path $out -Value '' -Encoding UTF8

Get-Process MouseWithoutBorders* -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Log 'processes stopped'

Set-Service MouseWithoutBordersSvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue
Log ('service: ' + (Get-Service MouseWithoutBordersSvc).Status)

Start-Sleep -Seconds 5
if (-not (Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue)) {
    Log 'app not launched by service; starting app'
    Start-Process 'C:\Program Files (x86)\Microsoft Garage\Mouse without Borders\MouseWithoutBorders.exe'
    Start-Sleep -Seconds 8
}
else {
    Log 'app launched by service'
}

Get-Process MouseWithoutBorders* -ErrorAction SilentlyContinue |
    Select-Object Id, ProcessName, SessionId |
    Format-Table -AutoSize | Out-String | Add-Content -Path $out -Encoding UTF8
(netstat -ano | Select-String '15100|15101') | ForEach-Object { $_.Line | Add-Content -Path $out -Encoding UTF8 }
