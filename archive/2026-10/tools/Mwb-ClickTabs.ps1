# Clicks across MWB's tab strip and looks for the Draw-cursor checkbox.
# Run elevated. Log: mwb-clicktabs.txt
$out = 'C:\Users\victo\ERAZER_remote_control\mwb-clicktabs.txt'
function Log([string]$m) { $m | Out-File -LiteralPath $out -Append -Encoding utf8 }
Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Mwb3 {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
    public static string[] List(IntPtr root) {
        var res = new List<string>();
        EnumChildWindows(root, (h, l) => {
            var t = new StringBuilder(512); GetWindowText(h, t, 512);
            if (t.Length > 0) res.Add(h.ToInt64() + "|" + t);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static int GetCheck(IntPtr h) { return (int)SendMessage(h, 0x00F0, IntPtr.Zero, IntPtr.Zero); }
    public static void Toggle(IntPtr h) { SendMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); }
    public static void ClickAt(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(2, 0, 0, 0, UIntPtr.Zero);
        mouse_event(4, 0, 0, 0, UIntPtr.Zero);
    }
}
'@

$p = Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Log 'no window'; exit 2 }
$h = [IntPtr]$p.MainWindowHandle
Log "window: $($p.MainWindowTitle)"

$found = $false
foreach ($y in 335, 350, 365) {
    foreach ($x in 600, 680, 760, 840, 920) {
        [Mwb3]::ClickAt($x, $y)
        Start-Sleep -Milliseconds 500
        $lines = [Mwb3]::List($h)
        $texts = $lines | ForEach-Object { $_.Split('|')[1] }
        Log "click $x,$y -> $($texts -join ' / ')"
        $hit = $lines | Where-Object { $_ -match '(?i)draw.*cursor|cursor.*draw' } | Select-Object -First 1
        if ($hit) {
            $parts = $hit.Split('|')
            $chk = [IntPtr][int64]$parts[0]
            $state = [Mwb3]::GetCheck($chk)
            Log "FOUND $($parts[1]) state=$state"
            if ($state -ne 0) { [Mwb3]::Toggle($chk); Start-Sleep -Milliseconds 400 }
            Log "after state=$([Mwb3]::GetCheck($chk))"
            $apply = [Mwb3]::List($h) | Where-Object { $_ -match '(?i)\|[^|]*(apply|ok)$' } | Select-Object -First 1
            if ($apply) { [Mwb3]::Toggle([IntPtr][int64]$apply.Split('|')[0]); Log "clicked $($apply.Split('|')[1])" }
            $found = $true
            break
        }
    }
    if ($found) { break }
}
if (-not $found) { Log 'Draw-cursor checkbox not found by clicking tab strip' }
Log 'done'
