Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class W2 {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
$p = Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'MT5 not running' | Out-File 'C:\Users\Vic\Desktop\focus-mt5.txt' -Encoding utf8; exit }
[W2]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
[W2]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
'focused MT5' | Out-File 'C:\Users\Vic\Desktop\focus-mt5.txt' -Encoding utf8
