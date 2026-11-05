# Double-clicks at a screen coordinate over the RustDesk remote window.
# Runs elevated because the RustDesk window is elevated.
param([int]$X = 330, [int]$Y = 245, [int]$Clicks = 2)

$log = 'C:\Users\victo\ERAZER_remote_control\mouse-test.log'
function L($m) { "$(Get-Date -Format o) $m" | Out-File $log -Append -Encoding utf8 }
"--- run x=$X y=$Y ---" | Out-File $log -Encoding utf8

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class M {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
}
'@

try {
    $p = Get-Process rustdesk -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
        Select-Object -First 1
    if (-not $p) { L 'no window'; exit 2 }
    $h = [IntPtr]$p.MainWindowHandle
    [M]::ShowWindow($h, 3) | Out-Null
    [M]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 700
    $fg = [M]::GetForegroundWindow()
    L "fg match=$($fg -eq $h)"
    if ($fg -ne $h) { exit 3 }

    [M]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 400
    1..$Clicks | ForEach-Object {
        [M]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [M]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 120
    }
    L 'double-click sent'
    exit 0
}
catch { L "ERROR: $($_.Exception.Message)"; exit 1 }
