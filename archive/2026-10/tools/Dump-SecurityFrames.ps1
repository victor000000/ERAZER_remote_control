$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ApplicationFrameWindow')
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
L ('ApplicationFrameWindow count=' + $wins.Count)
foreach ($w in $wins) {
    $name = $w.Current.Name
    L ('FRAME [' + $name + '] pid=' + $w.Current.ProcessId)
    $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    L ('  descendants=' + $all.Count)
    foreach ($e in $all) {
        $ct = $e.Current.ControlType.ProgrammaticName -replace 'ControlType\.', ''
        $n = $e.Current.Name
        $aid = $e.Current.AutomationId
        if ($ct -match 'Toggle|CheckBox|Button' -or $aid -match 'Tamper|Protect|RealTime|Real-Time' -or $n -match 'Tamper') {
            $pat = ''
            try { $null = $e.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern); $pat += 'Toggle' } catch {}
            try { $null = $e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern); $pat += ' Invoke' } catch {}
            L ('    [' + $ct + '] name=[' + $n + '] id=[' + $aid + '] enabled=' + $e.Current.IsEnabled + ' pat=' + $pat)
        }
    }
}
