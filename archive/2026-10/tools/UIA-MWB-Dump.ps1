# Dumps the Mouse Without Borders window's UI Automation tree so its
# Settings controls (Draw mouse cursor, Hide mouse, etc.) can be located.
$out = 'C:\Users\victo\ERAZER_remote_control\uia-mwb.txt'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process MouseWithoutBorders -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { 'no window' | Out-File $out -Encoding utf8; exit 2 }

$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
if (-not $root) { 'root null' | Out-File $out -Encoding utf8; exit 3 }

$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition)

"window: $($p.MainWindowTitle) count: $($all.Count)" | Out-File $out -Encoding utf8
foreach ($e in $all) {
    try {
        $line = '{0} | {1} | id={2} | enabled={3} | offscreen={4}' -f `
            $e.Current.ControlType.ProgrammaticName, $e.Current.Name,
            $e.Current.AutomationId, $e.Current.IsEnabled, $e.Current.IsOffscreen
        $line | Out-File $out -Append -Encoding utf8
    } catch { }
}
'done' | Out-File $out -Append -Encoding utf8
