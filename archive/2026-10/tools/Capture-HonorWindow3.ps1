$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinTop {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$p = Get-Process UninstallGuide -ErrorAction SilentlyContinue
if (-not $p) { Write-Output 'not running'; exit }
$h = $p.MainWindowHandle
$HWND_TOPMOST = [IntPtr](-1)
$SWP_SHOWWINDOW = 0x40
[WinTop]::ShowWindow($h, 9) | Out-Null
[WinTop]::SetWindowPos($h, $HWND_TOPMOST, 0, 0, 680, 420, $SWP_SHOWWINDOW) | Out-Null
Start-Sleep -Seconds 2
$bmp = New-Object System.Drawing.Bitmap(680, 420)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size(680, 420)))
$g.Dispose()
$out = 'C:\Users\victo\ERAZER_remote_control\honor-uninstall2.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$r = New-Object WinTop+RECT
[WinTop]::GetWindowRect($h, [ref]$r) | Out-Null
Write-Output ('saved, window at ' + $r.Left + ',' + $r.Top + ' ' + ($r.Right-$r.Left) + 'x' + ($r.Bottom-$r.Top))
