# Switches MWB's Settings tabs and toggles the "Draw mouse cursor"
# checkbox off. Run elevated (MWB runs elevated). Writes a log next to
# this script's project folder.
$out = 'C:\Users\victo\ERAZER_remote_control\mwb-cursor-fix.txt'
function Log([string]$m) { $m | Out-File -LiteralPath $out -Append -Encoding utf8 }

Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class MwbFix {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, ref RECT l);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public static string[] List(IntPtr root) {
        var res = new List<string>();
        EnumChildWindows(root, (h, l) => {
            var t = new StringBuilder(512); GetWindowText(h, t, 512);
            var c = new StringBuilder(256); GetClassName(h, c, 256);
            res.Add(h.ToInt64() + "|" + c + "|" + t);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
    public static int TabCount(IntPtr tab) {
        return (int)SendMessage(tab, 0x1304, IntPtr.Zero, IntPtr.Zero);
    }
    public static bool TabRect(IntPtr tab, int i, out RECT r) {
        r = new RECT();
        return SendMessage(tab, 0x130A, (IntPtr)i, ref r) != IntPtr.Zero;
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
if (-not $p) { Log 'no MWB window'; exit 2 }
$hwnd = [IntPtr]$p.MainWindowHandle
Log "window: $($p.MainWindowTitle)"

$children = [MwbFix]::List($hwnd)
$tabLine = $children | Where-Object { $_ -match 'SysTabControl32' } | Select-Object -First 1
if (-not $tabLine) {
    Log 'no tab control found'
    $children | ForEach-Object { Log "  $_" }
    exit 3
}
$tab = [IntPtr][int64]($tabLine.Split('|')[0])
$count = [MwbFix]::TabCount($tab)
Log "tab control: $($tabLine.Split('|')[1]) count=$count"

$toggled = $false
for ($i = 0; $i -lt $count; $i++) {
    $r = New-Object MwbFix+RECT
    if (-not [MwbFix]::TabRect($tab, $i, [ref]$r)) { Log "tab $i rect failed"; continue }
    $cx = [int](($r.Left + $r.Right) / 2)
    $cy = [int](($r.Top + $r.Bottom) / 2)
    [MwbFix]::ClickAt($cx, $cy)
    Start-Sleep -Milliseconds 700

    $lines = [MwbFix]::List($hwnd)
    $texts = $lines | ForEach-Object { $_.Split('|')[2] } | Where-Object { $_ }
    Log "tab $i ($cx,$cy) texts: $($texts -join ' / ')"

    $cursorLine = $lines | Where-Object { $_ -match '(?i)draw.*cursor|cursor.*draw' } | Select-Object -First 1
    if ($cursorLine) {
        $parts = $cursorLine.Split('|')
        $chk = [IntPtr][int64]$parts[0]
        $before = [MwbFix]::GetCheck($chk)
        Log "cursor checkbox: $($parts[2]) state=$before"
        if ($before -ne 0) { [MwbFix]::Toggle($chk); Start-Sleep -Milliseconds 400 }
        $after = [MwbFix]::GetCheck($chk)
        Log "cursor checkbox after toggle: state=$after"
        $applyLine = [MwbFix]::List($hwnd) | Where-Object { $_ -match '(?i)\|.*\|[^|]*(apply|ok)[^|]*$' } | Select-Object -First 1
        if ($applyLine) {
            $ah = [IntPtr][int64]$applyLine.Split('|')[0]
            Log "clicking apply: $($applyLine.Split('|')[2])"
            [MwbFix]::Toggle($ah)
            Start-Sleep -Milliseconds 500
        }
        $toggled = $true
        break
    }
}
if (-not $toggled) { Log 'Draw-cursor checkbox not found on any tab' }
Log 'done'
