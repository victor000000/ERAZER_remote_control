# Local PC cleanup - conservative, reversible. No software is uninstalled.
# Revert notes:
#   Recall policy: delete HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI
#   Services: Set-Service DiagTrack -StartupType Automatic ; Set-Service MapsBroker -StartupType Automatic
#   Tasks: Enable-ScheduledTask -TaskName <name>
#   WSL: edit %USERPROFILE%\.wslconfig
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
function L([string]$t) {
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $t
    $line | Out-File -FilePath $log -Append -Encoding utf8
    Write-Output $line
}
L '=== ELEVATED LOCAL CLEANUP START ==='

# 1. Recall ("回顾") - block by policy and remove the optional feature if present
$ai = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
New-Item -Path $ai -Force | Out-Null
New-ItemProperty -Path $ai -Name DisableAIDataAnalysis   -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path $ai -Name AllowRecallEnablement   -PropertyType DWord -Value 0 -Force | Out-Null
L 'Recall: policy DisableAIDataAnalysis=1, AllowRecallEnablement=0 written'
$f = Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue
if ($f) {
    L ('Recall feature state before: ' + $f.State)
    if ($f.State -ne 'Disabled') {
        Disable-WindowsOptionalFeature -Online -FeatureName Recall -NoRestart -ErrorAction SilentlyContinue | Out-Null
        $f2 = Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue
        L ('Recall feature state after: ' + $f2.State)
    }
} else {
    L 'Recall optional feature not present on this build'
}
$aiApps = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Recall|ClickToDo' }
L ('Recall/ClickToDo appx found: ' + (@($aiApps).Count))

# 2. Services - telemetry and offline maps only. Everything daily-use is untouched.
foreach ($s in @('DiagTrack', 'MapsBroker')) {
    $svc = Get-Service $s -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        $now = Get-Service $s
        L ($s + ' -> ' + $now.Status + ' / ' + $now.StartType)
    }
}
# NLA stopped unexpectedly - restore it (needed for network profile detection)
$nla = Get-Service NlaSvc -ErrorAction SilentlyContinue
if ($nla -and $nla.Status -ne 'Running') {
    Set-Service NlaSvc -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service NlaSvc -ErrorAction SilentlyContinue
    L ('NlaSvc -> ' + (Get-Service NlaSvc).Status + ' / ' + (Get-Service NlaSvc).StartType)
}

# 3. Scheduled tasks - promo/background updaters only
$tasks = @()
$tasks += Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like '\SoftLanding\*' }
$tasks += Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'Ubisoft Connect Background Update' }
$tasks += Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'OneDrive Reporting Task*' }
foreach ($t in $tasks) {
    if ($t.State -ne 'Disabled') {
        Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
        $now = Get-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue
        L ('task disabled: ' + $t.TaskPath + $t.TaskName + ' -> ' + $now.State)
    }
}

# 4. Temp + Windows Update download cache
$freed = 0
foreach ($d in @($env:TEMP, 'C:\Windows\Temp')) {
    if (Test-Path $d) {
        $before = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $freed += ($before - $after)
        L ('temp cleaned: ' + $d + ' freed ' + [math]::Round(($before - $after)/1MB,1) + ' MB (in-use files left)')
    }
}
$wu = 'C:\Windows\SoftwareDistribution\Download'
if (Test-Path $wu) {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    $before = (Get-ChildItem $wu -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Get-ChildItem $wu -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    L ('WU download cache cleared: ' + [math]::Round($before/1MB,1) + ' MB')
}
L ('total temp/WU freed ~' + [math]::Round($freed/1MB,1) + ' MB')

# 5. Tailscale UDP inbound for all profiles (direct path, previously missing)
$existing = Get-NetFirewallRule -DisplayName 'Tailscale UDP 41641 (all profiles)' -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule -DisplayName 'Tailscale UDP 41641 (all profiles)' -Direction Inbound -Protocol UDP -LocalPort 41641 -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
    L 'firewall: Tailscale UDP 41641 inbound rule added (all profiles)'
} else {
    L 'firewall: Tailscale UDP 41641 rule already present'
}

L '=== ELEVATED LOCAL CLEANUP END ==='
