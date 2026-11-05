$ProgressPreference = 'SilentlyContinue'

Write-Output '=== COPILOT REGISTRY ==='
Get-ItemProperty 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -ErrorAction SilentlyContinue |
    Select-Object TurnOffWindowsCopilot | Format-List
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue |
    Select-Object ShowCopilotButton | Format-List
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -ErrorAction SilentlyContinue |
    Select-Object TurnOffWindowsCopilot | Format-List
Get-ItemProperty 'HKCU:\Software\Policies\Microsoft\Edge' -ErrorAction SilentlyContinue |
    Select-Object HubsSidebarEnabled, CopilotPageContext, CopilotCDPPageContext, EdgeEntraCopilotPageContext |
    Format-List

Write-Output '=== COPILOT PROCESSES NOW ==='
$cp = Get-Process -Name '*Copilot*' -ErrorAction SilentlyContinue
if ($cp) { $cp | Select-Object Id, ProcessName, Path | Format-Table -AutoSize } else { Write-Output 'none' }

Write-Output '=== COPILOT PACKAGES ==='
$pkg = Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue
if ($pkg) { $pkg | Select-Object Name, PackageFullName, Status | Format-List } else { Write-Output 'no Appx package named Copilot' }

Write-Output '=== SQX HEALTH ==='
$p = Get-Process sqcli -ErrorAction SilentlyContinue
if ($p) {
    $p | Select-Object Id, PriorityClass,
        @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB)}} | Format-List
} else { Write-Output 'NO_SQCLI' }
(Get-ScheduledTask -TaskName 'SQX145Project' -ErrorAction SilentlyContinue).State
try {
    (Invoke-WebRequest 'http://localhost:5050/call?cmd=-project%20action=status%20name=S001_reproduce_project' -UseBasicParsing -TimeoutSec 30).Content
} catch { $_.Exception.Message }
