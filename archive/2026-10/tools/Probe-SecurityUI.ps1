$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}

Start-Process 'windowsdefender://threatsettings' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
L ('windows=' + $wins.Count)
foreach ($w in $wins) {
    $name = $w.Current.Name
    $cls = $w.Current.ClassName
    $pid = $w.Current.ProcessId
    if ($name -match '安全|Security|Defender|威胁|Protection' -or $cls -match 'SecHealth|ApplicationFrame') {
        L ('WIN name=[' + $name + '] class=' + $cls + ' pid=' + $pid)
        try {
            $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            L ('  descendants=' + $all.Count)
            foreach ($e in $all) {
                $n = $e.Current.Name
                $ct = $e.Current.ControlType.ProgrammaticName
                if ($n -match '篡改|Tamper|实时|Real-time|保护|Protection') {
                    $patterns = ''
                    try { if ($e.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)) { $patterns += 'Toggle ' } } catch {}
                    try { if ($e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)) { $patterns += 'Invoke ' } } catch {}
                    L ('    ' + $ct + ' name=[' + $n + '] autoId=[' + $e.Current.AutomationId + '] class=' + $e.Current.ClassName + ' patterns=' + $patterns)
                }
            }
        } catch {
            L ('  UIA descend failed: ' + $_.Exception.Message)
        }
    }
}
