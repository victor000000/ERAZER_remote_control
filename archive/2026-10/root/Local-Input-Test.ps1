# Tests whether synthetic keyboard input works at all on this PC:
# launches Notepad, brings it to the foreground, types a marker string,
# and saves a screenshot. Runs elevated for parity with other helpers.
$out = 'C:\Users\victo\ERAZER_remote_control\local-input-test.log'
"--- run ---" | Out-File $out -Encoding utf8

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class T {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@

$n = Start-Process notepad.exe -PassThru
Start-Sleep -Seconds 2

# Win11 Notepad may spawn a child process; find the windowed one.
$w = Get-Process notepad -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $w) { 'no notepad window' | Out-File $out -Append -Encoding utf8; exit 2 }

[T]::SetForegroundWindow($w.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 600
"fg match=$([T]::GetForegroundWindow() -eq $w.MainWindowHandle) title=$($w.MainWindowTitle)" | Out-File $out -Append -Encoding utf8

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait('Local input test 123')
Start-Sleep -Milliseconds 800
'keys sent' | Out-File $out -Append -Encoding utf8

Add-Type -AssemblyName System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save('C:\Users\victo\ERAZER_remote_control\local-input-test.png')
'saved' | Out-File $out -Append -Encoding utf8
