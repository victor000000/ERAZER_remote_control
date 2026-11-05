$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}

$exe = 'C:\Program Files\HONOR\PCManager\UninstallGuide.exe'
if (-not (Test-Path $exe)) { L 'UninstallGuide missing'; exit }

$p = Start-Process -FilePath $exe -PassThru
Start-Sleep -Seconds 6
$p.Refresh()
L ('UninstallGuide pid=' + $p.Id + ' exited=' + $p.HasExited + ' title=[' + $p.MainWindowTitle + '] hwnd=' + $p.MainWindowHandle)

try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
    $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    L ('top-level UIA windows=' + $wins.Count)
    foreach ($w in $wins) {
        L ('  window name=[' + $w.Current.Name + '] class=' + $w.Current.ClassName + ' hwnd=' + $w.Current.NativeWindowHandle)
        $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        L ('  descendants=' + $all.Count)
        $i = 0
        foreach ($e in $all) {
            $ct = $e.Current.ControlType.ProgrammaticName
            $nm = $e.Current.Name
            if ($ct -match 'Button|Text|Hyperlink' -and $nm) {
                L ('    ' + $ct + ' name=[' + $nm + '] autoId=[' + $e.Current.AutomationId + ']')
                $i++
                if ($i -ge 40) { break }
            }
        }
    }
} catch {
    L ('UIA failed: ' + $_.Exception.Message)
}
