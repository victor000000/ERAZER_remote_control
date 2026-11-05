# Undo the marker text accidentally typed into the user's Notepad.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class U {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@
$n = Get-Process notepad -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match 'repair-network' } | Select-Object -First 1
if ($n) {
    [U]::SetForegroundWindow($n.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 500
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('^z')
    'undo sent' | Out-File 'C:\Users\victo\ERAZER_remote_control\undo.log' -Encoding utf8
} else {
    'notepad not found' | Out-File 'C:\Users\victo\ERAZER_remote_control\undo.log' -Encoding utf8
}
