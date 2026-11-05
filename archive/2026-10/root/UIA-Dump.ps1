# Dumps the RustDesk remote-session window's UI Automation tree so buttons
# (terminal, view-only toggle, etc.) can be found and invoked.
$out = 'C:\Users\victo\ERAZER_remote_control\uia-dump.txt'
"--- uia dump ---" | Out-File $out -Encoding utf8

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process rustdesk -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '10\.133\.221\.32' } |
    Select-Object -First 1
if (-not $p) { 'no window' | Out-File $out -Append; exit 2 }

$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
if (-not $root) { 'root is null' | Out-File $out -Append; exit 3 }

"root: $($root.Current.Name) / $($root.Current.ControlType.ProgrammaticName)" | Out-File $out -Append -Encoding utf8

$cond = [System.Windows.Automation.Condition]::TrueCondition
$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
"descendants: $($all.Count)" | Out-File $out -Append -Encoding utf8

foreach ($e in $all) {
    try {
        $r = $e.Current.BoundingRectangle
        $line = "{0} | {1} | id='{2}' | enabled={3} | rect={4},{5},{6},{7}" -f `
            $e.Current.ControlType.ProgrammaticName, $e.Current.Name, $e.Current.AutomationId,
            $e.Current.IsEnabled, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
        $line | Out-File $out -Append -Encoding utf8
    } catch { }
}
'done' | Out-File $out -Append -Encoding utf8
