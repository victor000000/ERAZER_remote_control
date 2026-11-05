# Restarts Mouse Without Borders and reports its peer sessions.
# Run elevated: the MWB UI processes run at high integrity.
$ErrorActionPreference = 'SilentlyContinue'
Get-Process MouseWithoutBorders* | Stop-Process -Force
Start-Sleep -Seconds 2
Start-Process 'C:\Program Files (x86)\Microsoft Garage\Mouse without Borders\MouseWithoutBorders.exe'
Start-Sleep -Seconds 10
Get-Process MouseWithoutBorders* | Select-Object Id, ProcessName, SessionId |
    Format-Table -AutoSize
netstat -ano | findstr '15100 15101'
