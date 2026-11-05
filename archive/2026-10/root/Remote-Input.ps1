# Sends input to the RustDesk remote-session window. Must run elevated
# (the RustDesk window is elevated; UIPI blocks lower-integrity input).
# Logs every step so the caller can diagnose.
param(
    [int]$X = 550,
    [int]$Y = 900,
    [string]$Text = 'echo TEST123',
    [switch]$Paste,
    [switch]$EnterOnly,
    [switch]$NoClick
)

$log = 'C:\Users\victo\ERAZER_remote_control\remote-input.log'
function L($m) { "$(Get-Date -Format o) $m" | Out-File $log -Append -Encoding utf8 }
"--- run ---" | Out-File $log -Encoding utf8

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class U {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool alt);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
}
'@

try {
    $p = Get-Process rustdesk -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
        Select-Object -First 1
    if (-not $p) { L 'no remote window'; exit 2 }
    $h = [IntPtr]$p.MainWindowHandle
    L "window handle=$h title=$($p.MainWindowTitle) session=$($p.SessionId)"

    [U]::ShowWindow($h, 3) | Out-Null
    [U]::SwitchToThisWindow($h, $true)
    [U]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 600

    $fg = [U]::GetForegroundWindow()
    if ($fg -ne $h) {
        $fgPid = [uint32]0
        $tgPid = [uint32]0
        $fgThread = [U]::GetWindowThreadProcessId($fg, [ref]$fgPid)
        $tgThread = [U]::GetWindowThreadProcessId($h, [ref]$tgPid)
        [U]::AttachThreadInput($fgThread, $tgThread, $true) | Out-Null
        [U]::SetForegroundWindow($h) | Out-Null
        [U]::AttachThreadInput($fgThread, $tgThread, $false) | Out-Null
        Start-Sleep -Milliseconds 600
        $fg = [U]::GetForegroundWindow()
    }
    L "foreground=$fg target=$h match=$($fg -eq $h)"
    if ($fg -ne $h) { L 'ABORT foreground'; exit 3 }

    if (-not $NoClick) {
        [U]::SetCursorPos($X, $Y) | Out-Null
        Start-Sleep -Milliseconds 400
        [U]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
        [U]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 400
    }

    Add-Type -AssemblyName System.Windows.Forms
    if ($Paste) {
        [System.Windows.Forms.SendKeys]::SendWait('^v')
        L 'sent Ctrl+V'
    }
    elseif (-not $EnterOnly) {
        [System.Windows.Forms.SendKeys]::SendWait($Text)
        L "sent keys: $Text"
    }
    Start-Sleep -Milliseconds 500
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    L 'sent ENTER'
    exit 0
}
catch {
    L "ERROR: $($_.Exception.Message)"
    exit 1
}
