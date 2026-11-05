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

$proc = Get-Process SecHealthUI -ErrorAction SilentlyContinue
if (-not $proc) { L 'SecHealthUI not running'; exit }
$procId = $proc.Id
L ('SecHealthUI pid=' + $procId)

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $procId)
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
L ('windows=' + $wins.Count)
foreach ($w in $wins) {
    L ('WIN [' + $w.Current.Name + '] class=' + $w.Current.ClassName)
    $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    L ('descendants=' + $all.Count)
    foreach ($e in $all) {
        $ct = $e.Current.ControlType.ProgrammaticName -replace 'ControlType\.', ''
        $n = $e.Current.Name
        $aid = $e.Current.AutomationId
        if ($n -or $aid) {
            $pat = ''
            try { $null = $e.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern); $pat += 'Toggle' } catch {}
            try { $null = $e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern); $pat += ' Invoke' } catch {}
            L ('  [' + $ct + '] name=[' + $n + '] id=[' + $aid + '] class=' + $e.Current.ClassName + ' enabled=' + $e.Current.IsEnabled + ' pat=' + $pat)
        }
    }
}
