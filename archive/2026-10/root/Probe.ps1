# Elevated probe: identifies the RustDesk UI processes and single-clicks
# the session toolbar, to test whether synthetic input reaches the UI.
$out = 'C:\Users\victo\ERAZER_remote_control\probe.log'
"--- probe ---" | Out-File $out -Encoding utf8

try {
    Get-Process rustdesk -IncludeUserName -ErrorAction SilentlyContinue |
        Select-Object Id, UserName, SessionId, MainWindowTitle |
        Format-Table -AutoSize | Out-File $out -Append -Encoding utf8
}
catch { "owner query failed: $($_.Exception.Message)" | Out-File $out -Append -Encoding utf8 }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class P {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
}
'@

$p = Get-Process rustdesk -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
    Select-Object -First 1
if (-not $p) { 'no window' | Out-File $out -Append -Encoding utf8; exit 2 }

[P]::ShowWindow($p.MainWindowHandle, 3) | Out-Null
[P]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700
"fg match=$([P]::GetForegroundWindow() -eq $p.MainWindowHandle)" | Out-File $out -Append -Encoding utf8

[P]::SetCursorPos(1183, 55) | Out-Null
Start-Sleep -Milliseconds 400
[P]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[P]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
'toolbar click sent' | Out-File $out -Append -Encoding utf8
