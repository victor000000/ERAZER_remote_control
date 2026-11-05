# Cycles MWB's pages with Ctrl+Tab and toggles "Draw mouse cursor" if found.
# Run elevated (MWB is elevated). Log: mwb-cursortab.txt in the project dir.
$out = 'C:\Users\victo\ERAZER_remote_control\mwb-cursortab.txt'
function Log([string]$m) { $m | Out-File -LiteralPath $out -Append -Encoding utf8 }
Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Mwb2 {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);

    public static string[] List(IntPtr root) {
        var res = new List<string>();
        EnumChildWindows(root, (h, l) => {
            var t = new StringBuilder(512); GetWindowText(h, t, 512);
            var c = new StringBuilder(256); GetClassName(h, c, 256);
            if (t.Length > 0) res.Add(h.ToInt64() + "|" + c + "|" + t);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static int GetCheck(IntPtr h) { return (int)SendMessage(h, 0x00F0, IntPtr.Zero, IntPtr.Zero); }
    public static void Toggle(IntPtr h) { SendMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); }
}
'@

Add-Type -AssemblyName System.Windows.Forms
$p = Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Log 'no window'; exit 2 }
$h = [IntPtr]$p.MainWindowHandle
Log "window: $($p.MainWindowTitle)"

for ($i = 1; $i -le 6; $i++) {
    [Mwb2]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 400
    [System.Windows.Forms.SendKeys]::SendWait('^{TAB}')
    Start-Sleep -Milliseconds 900
    $lines = [Mwb2]::List($h)
    $texts = $lines | ForEach-Object { $_.Split('|')[2] }
    Log "cycle ${i}: $($texts -join ' / ')"

    $hit = $lines | Where-Object { $_ -match '(?i)draw.*cursor|cursor.*draw|draw mouse' } | Select-Object -First 1
    if ($hit) {
        $parts = $hit.Split('|')
        $chk = [IntPtr][int64]$parts[0]
        $state = [Mwb2]::GetCheck($chk)
        Log "FOUND: $($parts[2]) state=$state"
        if ($state -ne 0) { [Mwb2]::Toggle($chk); Start-Sleep -Milliseconds 500 }
        Log "after: state=$([Mwb2]::GetCheck($chk))"
        $apply = [Mwb2]::List($h) | Where-Object { $_ -match '(?i)\|[^|]*\|&?(apply|ok)$' } | Select-Object -First 1
        if ($apply) {
            [Mwb2]::Toggle([IntPtr][int64]$apply.Split('|')[0])
            Log "clicked $($apply.Split('|')[2])"
        }
        break
    }
}
Log 'done'
