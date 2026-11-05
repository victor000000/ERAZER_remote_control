# Sends one virtual-key press to the RustDesk remote window using the legacy
# keybd_event API. Runs elevated because the RustDesk window is elevated.
param([int]$Vk = 0x0D)

$log = 'C:\Users\victo\ERAZER_remote_control\press-key.log'
function L($m) { "$(Get-Date -Format o) $m" | Out-File $log -Append -Encoding utf8 }
"--- run vk=$Vk ---" | Out-File $log -Encoding utf8

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@

try {
    $p = Get-Process rustdesk -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
        Select-Object -First 1
    if (-not $p) { L 'no window'; exit 2 }
    $h = [IntPtr]$p.MainWindowHandle
    [K]::ShowWindow($h, 3) | Out-Null
    [K]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 700
    $fg = [K]::GetForegroundWindow()
    L "fg match=$($fg -eq $h)"
    if ($fg -ne $h) { exit 3 }

    [K]::keybd_event([byte]$Vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    [K]::keybd_event([byte]$Vk, 0, 2, [UIntPtr]::Zero)
    L 'vk sent'
    exit 0
}
catch { L "ERROR: $($_.Exception.Message)"; exit 1 }
