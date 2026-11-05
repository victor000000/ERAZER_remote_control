$ProgressPreference = 'SilentlyContinue'

function Set-RegDword([string]$Path, [string]$Name, [int]$Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord
}

Write-Output '=== OS ==='
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber | Format-List

Write-Output '=== COPILOT PACKAGE / PROCESS BEFORE ==='
Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue |
    Select-Object Name, PackageFullName, Status | Format-List
Get-Process -Name '*Copilot*' -ErrorAction SilentlyContinue |
    Select-Object Id, ProcessName | Format-Table -AutoSize

# Per-user policy: turn off Windows Copilot
Set-RegDword 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1

# Hide the taskbar button
Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0

# Machine-wide policy (needs elevation; report if it fails)
$hklm = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
try {
    Set-RegDword $hklm 'TurnOffWindowsCopilot' 1
    $hklmResult = 'ok'
} catch {
    $hklmResult = 'FAILED: ' + $_.Exception.Message
}

# Edge Copilot/sidebar policies
$edge = 'HKCU:\Software\Policies\Microsoft\Edge'
Set-RegDword $edge 'HubsSidebarEnabled' 0
Set-RegDword $edge 'CopilotPageContext' 0
Set-RegDword $edge 'CopilotCDPPageContext' 0
Set-RegDword $edge 'EdgeEntraCopilotPageContext' 0

# Stop a running Copilot app; policy prevents relaunch
Get-Process -Name '*Copilot*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Output '=== VERIFY ==='
Get-ItemProperty 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -ErrorAction SilentlyContinue |
    Select-Object TurnOffWindowsCopilot
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue |
    Select-Object ShowCopilotButton
Get-ItemProperty $hklm -ErrorAction SilentlyContinue | Select-Object TurnOffWindowsCopilot
Get-ItemProperty $edge -ErrorAction SilentlyContinue |
    Select-Object HubsSidebarEnabled, CopilotPageContext, CopilotCDPPageContext, EdgeEntraCopilotPageContext
Write-Output ('HKLM policy: ' + $hklmResult)

Write-Output '=== COPILOT PACKAGE / PROCESS AFTER ==='
Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue |
    Select-Object Name, PackageFullName, Status | Format-List
Get-Process -Name '*Copilot*' -ErrorAction SilentlyContinue |
    Select-Object Id, ProcessName | Format-Table -AutoSize

# Refresh Explorer so the taskbar button setting applies now
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 4
Write-Output '=== EXPLORER ==='
Get-Process -Name explorer -ErrorAction SilentlyContinue |
    Select-Object Id, ProcessName, SessionId | Format-Table -AutoSize
