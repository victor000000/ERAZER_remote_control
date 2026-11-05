param([int]$TargetPid = 9456)
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Vic\ERAZER-Tools\Logs\hide-console.log'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
}
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class WinHider {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public static List<string> Hide(uint target) {
        var list = new List<string>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == target && IsWindowVisible(h)) {
                var t = new StringBuilder(256); GetWindowText(h, t, 256);
                bool ok = ShowWindow(h, 0);
                list.Add("hwnd=" + h + " title=[" + t + "] hidden=" + ok);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
"@
L ('hiding windows for pid=' + $TargetPid)
$results = [WinHider]::Hide([uint32]$TargetPid)
if ($results.Count -eq 0) { L 'no visible windows found for pid' }
foreach ($r in $results) { L ('  ' + $r) }
