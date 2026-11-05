$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

# --- WSL memory: cap and reclaim (applies next time WSL restarts; no restart forced) ---
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
$backup = $cfg + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
if (Test-Path $cfg) {
    Copy-Item $cfg $backup -Force
    $c = Get-Content $cfg -Raw
} else {
    $c = "[wsl2]`r`n"
}
if ($c -notmatch '(?m)^memory\s*=') {
    $c = $c -replace '(?m)^(\[wsl2\]\s*)', "`$1`r`nmemory=16GB`r`n"
}
if ($c -notmatch 'autoMemoryReclaim') {
    if ($c -match '(?m)^\[experimental\]') {
        $c = $c -replace '(?m)^(\[experimental\][^\r\n]*)', "`$1`r`nautoMemoryReclaim=gradual"
    } else {
        $c = $c.TrimEnd() + "`r`n`r`n[experimental]`r`nautoMemoryReclaim=gradual`r`n"
    }
}
Set-Content -Path $cfg -Value $c -Encoding utf8
W ('--- .wslconfig now ---')
W (Get-Content $cfg -Raw)

# --- Quiet Windows suggestions / ads (HKCU, reversible) ---
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (Test-Path $cdm) {
    $vals = @{
        'SubscribedContent-338388Enabled' = 0
        'SubscribedContent-338389Enabled' = 0
        'SubscribedContent-353694Enabled' = 0
        'SubscribedContent-353696Enabled' = 0
        'SoftLandingEnabled'              = 0
        'SystemPaneSuggestionsEnabled'    = 0
    }
    foreach ($k in $vals.Keys) {
        New-ItemProperty -Path $cdm -Name $k -PropertyType DWord -Value $vals[$k] -Force | Out-Null
    }
    W 'suggestion/ads registry flags set to 0'
}

# --- Verification snapshot ---
W '--- VERIFY ---'
W ('DiagTrack=' + (Get-Service DiagTrack).Status + '/' + (Get-Service DiagTrack).StartType)
W ('MapsBroker=' + (Get-Service MapsBroker).Status + '/' + (Get-Service MapsBroker).StartType)
W ('NlaSvc=' + (Get-Service NlaSvc).Status + '/' + (Get-Service NlaSvc).StartType)
$ai = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -ErrorAction SilentlyContinue
W ('RecallPolicy DisableAIDataAnalysis=' + $ai.DisableAIDataAnalysis + ' AllowRecallEnablement=' + $ai.AllowRecallEnablement)
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like '\SoftLanding\*' -or $_.TaskName -like 'OneDrive Reporting*' -or $_.TaskName -eq 'Ubisoft Connect Background Update' } |
    Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Write-Output
$os = Get-CimInstance Win32_OperatingSystem
W ('RAM free=' + [math]::Round($os.FreePhysicalMemory/1KB) + 'MB / ' + [math]::Round($os.TotalVisibleMemorySize/1KB) + 'MB')
$t = Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
W ('user TEMP now=' + [math]::Round($t.Sum/1MB,1) + ' MB')
$r = Get-NetFirewallRule -DisplayName 'Tailscale UDP 41641 (all profiles)' -ErrorAction SilentlyContinue
W ('Tailscale UDP rule present=' + [bool]$r + ' enabled=' + $r.Enabled + ' profile=' + $r.Profile)
