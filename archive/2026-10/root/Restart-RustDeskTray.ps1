# Close the RustDesk main window(s). The app is designed to keep running
# in the system tray. If a window survives the close, restart the UI with
# the --tray startup flag.
$ErrorActionPreference = 'SilentlyContinue'
$out = 'C:\Users\victo\ERAZER_remote_control\rustdesk-tray-state.txt'

Get-Process rustdesk |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    ForEach-Object { $_.CloseMainWindow() | Out-Null }

Start-Sleep -Seconds 3

$state = Get-Process rustdesk | Select-Object Id, SessionId, MainWindowHandle, MainWindowTitle
$state | Format-Table -AutoSize | Out-File $out -Encoding utf8

if ($state | Where-Object { $_.MainWindowHandle -ne 0 }) {
    Get-Process rustdesk | Where-Object { $_.SessionId -eq 1 } | Stop-Process -Force
    Start-Sleep -Seconds 2
    Start-Process 'C:\Program Files\RustDesk\rustdesk.exe' -ArgumentList '--tray'
    Start-Sleep -Seconds 6
    Get-Process rustdesk |
        Select-Object Id, SessionId, MainWindowHandle, MainWindowTitle |
        Format-Table -AutoSize |
        Out-File $out -Encoding utf8 -Append
}
