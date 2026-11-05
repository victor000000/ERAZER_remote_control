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

$tamperLabel = [string]([char]0x7BE1) + [char]0x6539 + [char]0x9632 + [char]0x62A4  # "篡改防护"

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ApplicationFrameWindow')
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
$target = $null
$toggleCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'settingToggle')
foreach ($w in $wins) {
    $toggles = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $toggleCond)
    if ($toggles.Count -gt 0) {
        L ('frame [' + $w.Current.Name + '] toggles=' + $toggles.Count)
        foreach ($t in $toggles) {
            $tp = $null
            try { $tp = $t.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) } catch {}
            $state = if ($tp) { $tp.Current.ToggleState } else { 'n/a' }
            $isTamper = $t.Current.Name.Contains($tamperLabel)
            L ('  toggle name=[' + $t.Current.Name + '] state=' + $state + ' isTamper=' + $isTamper)
            if ($isTamper) { $target = $t }
        }
    }
}
if (-not $target) { L 'Tamper toggle not found'; exit }

$pat = $target.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
L ('tamper state before=' + $pat.Current.ToggleState)
if ($pat.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::Off) {
    try {
        $pat.Toggle()
        L 'toggle invoked'
    } catch {
        L ('toggle failed: ' + $_.Exception.Message)
    }
    Start-Sleep -Seconds 4
    $pat2 = $target.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
    L ('tamper state after=' + $pat2.Current.ToggleState)
} else {
    L 'tamper already off'
}
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    L ('IsTamperProtected=' + $mp.IsTamperProtected + ' RTP=' + $mp.RealTimeProtectionEnabled)
} catch { L 'status unavailable' }
