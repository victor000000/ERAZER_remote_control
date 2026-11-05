# Lists child controls (class, text, screen rect) of the Mouse Without Borders
# window using Win32 enumeration. Run elevated (MWB runs elevated).
$out = 'C:\Users\victo\ERAZER_remote_control\mwb-controls.txt'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class MwbWin {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);

    public static string[] List(IntPtr root) {
        var res = new List<string>();
        EnumChildWindows(root, (h, l) => {
            var t = new StringBuilder(512); GetWindowText(h, t, 512);
            var c = new StringBuilder(256); GetClassName(h, c, 256);
            RECT r; GetWindowRect(h, out r);
            bool vis = IsWindowVisible(h);
            res.Add(h.ToInt64() + "|" + c + "|" + t + "|" + vis + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static void Click(IntPtr h) { SendMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); } // BM_CLICK
}
'@

$p = Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { 'no window' | Out-File $out -Encoding utf8; exit 2 }

"MwbWin.List($($p.MainWindowHandle))" | Out-File $out -Encoding utf8
[MwbWin]::List($p.MainWindowHandle) | Out-File $out -Append -Encoding utf8
'done' | Out-File $out -Append -Encoding utf8
