$out = 'C:\Users\Vic\Desktop\mt5-close.txt'
function Log([string]$m) { "$(Get-Date -Format o) $m" | Out-File -LiteralPath $out -Append -Encoding utf8 }
Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Dlg {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);

    public static string[] TopWindows(uint pid) {
        var res = new List<string>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid) {
                var c = new StringBuilder(64); GetClassName(h, c, 64);
                var t = new StringBuilder(256); GetWindowText(h, t, 256);
                res.Add(h.ToInt64() + "|" + c + "|" + t);
            }
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static string[] Children(IntPtr h) {
        var res = new List<string>();
        EnumChildWindows(h, (c, l) => {
            var t = new StringBuilder(256); GetWindowText(c, t, 256);
            var cl = new StringBuilder(64); GetClassName(c, cl, 64);
            if (t.Length > 0) res.Add(c.ToInt64() + "|" + cl + "|" + t);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static void Click(IntPtr h) { SendMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); }
    public static void Command(IntPtr h, int id) { SendMessage(h, 0x0111, (IntPtr)id, IntPtr.Zero); }
}
'@

$p = Get-Process terminal64 -ErrorAction SilentlyContinue
if (-not $p) { Log 'MT5 not running'; exit 0 }

Log "MT5 PID $($p.Id); closing main window"
$p.CloseMainWindow() | Out-Null
Start-Sleep -Seconds 3

if (Get-Process terminal64 -ErrorAction SilentlyContinue) {
    Log 'still running; looking for a confirmation dialog'
    foreach ($w in [Dlg]::TopWindows([uint32]$p.Id)) {
        $parts = $w.Split('|')
        Log "window: $w"
        if ($parts[1] -like '*#32770*') {
            $h = [IntPtr][int64]$parts[0]
            foreach ($child in [Dlg]::Children($h)) {
                Log "  child: $child"
                if ($child -match '(?i)\|.*\|(yes|ok)') {
                    [Dlg]::Click([IntPtr][int64]$child.Split('|')[0])
                    Log '  clicked confirmation'
                    break
                }
            }
            [Dlg]::Command($h, 6)  # IDYES fallback
        }
    }
    Start-Sleep -Seconds 4
}
if (Get-Process terminal64 -ErrorAction SilentlyContinue) { Log 'RESULT: still running' } else { Log 'RESULT: closed' }
