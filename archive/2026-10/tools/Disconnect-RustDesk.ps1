# Closes the RustDesk remote-session window on this PC to test whether
# MT5/SQX keep running on the ERAZER after the viewer disconnects.
$p = Get-Process rustdesk -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
    Select-Object -First 1
if ($p) {
    Stop-Process -Id $p.Id -Force
    "closed RustDesk session window (PID $($p.Id))"
}
else {
    'no RustDesk session window found'
}
