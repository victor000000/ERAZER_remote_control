$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class WinEnum {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static List<string> ForPid(uint target) {
        var list = new List<string>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == target) {
                var t = new StringBuilder(256); GetWindowText(h, t, 256);
                var c = new StringBuilder(256); GetClassName(h, c, 256);
                RECT r; GetWindowRect(h, out r);
                list.Add("hwnd=" + h + " visible=" + IsWindowVisible(h) + " title=[" + t + "] class=" + c + " rect=" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
"@
$p = Get-Process UninstallGuide -ErrorAction SilentlyContinue
if (-not $p) { Write-Output 'not running'; exit }
Write-Output ('pid=' + $p.Id + ' session=' + $p.SessionId + ' respond=' + $p.Responding)
[WinEnum]::ForPid([uint32]$p.Id) | ForEach-Object { Write-Output $_ }
$fg = [WinEnum]::GetForegroundWindow()
Write-Output ('foreground hwnd=' + $fg)
