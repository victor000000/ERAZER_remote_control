# Resets Mouse Without Borders on BOTH machines and re-establishes the link.
#
# Run this on StupicVicPC (elevated; the script self-elevates):
#   powershell -ExecutionPolicy Bypass -File .\Reset-MWB.ps1
#   powershell -ExecutionPolicy Bypass -File .\Reset-MWB.ps1 -ErazerIp 192.168.0.5
#
# Requires Start-MWB.cmd next to this script and the SSH key at
# C:\Users\victo\.ssh\erazer_ed25519. SSH calls are non-interactive and
# time-limited so the script cannot hang on a prompt.
param(
    [string]$ErazerIp = '192.168.0.5'
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -WindowStyle Hidden -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
        '-ErazerIp', $ErazerIp
    )
    exit
}

$log = Join-Path $env:TEMP 'Reset-MWB.log'
function Log([string]$m) {
    $line = "$(Get-Date -Format o) $m"
    $line | Add-Content -Path $log -Encoding UTF8
    Write-Host $line
}

$ssh      = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$scp      = Join-Path $env:WINDIR 'System32\OpenSSH\scp.exe'
$key      = Join-Path $env:USERPROFILE '.ssh\erazer_ed25519'
$known    = Join-Path $env:USERPROFILE '.ssh\erazer_known_hosts'
$localApp = 'C:\Program Files (x86)\Microsoft Garage\Mouse without Borders\MouseWithoutBorders.exe'
$wrapper  = Join-Path $PSScriptRoot 'Start-MWB.cmd'

$sshOpts = @(
    '-i', $key,
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=10',
    '-o', 'ServerAliveInterval=10',
    '-o', 'ServerAliveCountMax=2',
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', "UserKnownHostsFile=$known"
)

function Remote([string]$command) {
    & $ssh @sshOpts "Vic@$ErazerIp" $command 2>&1
}

"=== Reset-MWB start (target $ErazerIp) ===" | Out-File $log -Encoding utf8

# --- Local side -------------------------------------------------------------
Log 'Stopping local MWB processes...'
Get-Process MouseWithoutBorders* -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Log 'Ensuring local MWB service is running...'
Set-Service MouseWithoutBordersSvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service MouseWithoutBordersSvc -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

if (Test-Path -LiteralPath $localApp) {
    Log 'Starting local MWB app...'
    Start-Process -FilePath $localApp
}
else {
    Log "local app missing: $localApp"
}
Start-Sleep -Seconds 5

# --- ERAZER side ------------------------------------------------------------
Log 'Copying launcher to ERAZER...'
& $scp @sshOpts $wrapper "Vic@${ErazerIp}:C:/Users/Vic/Desktop/Start-MWB.cmd" 2>&1 | Out-Null

Log 'Stopping ERAZER MWB processes...'
Remote 'taskkill /IM MouseWithoutBorders.exe /F & taskkill /IM MouseWithoutBordersHelper.exe /F' | Out-Null
Start-Sleep -Seconds 2

Log 'Ensuring ERAZER MWB service is running (launches the app)...'
Remote 'powershell -NoProfile -Command "Set-Service MouseWithoutBordersSvc -StartupType Automatic; Start-Service MouseWithoutBordersSvc"' | Out-Null

Log 'Starting ERAZER MWB app in the interactive session...'
try {
    Remote 'schtasks /Create /TN StartMWB /TR C:\Users\Vic\Desktop\Start-MWB.cmd /SC ONCE /ST 23:59 /IT /F' | Out-Null
    Remote 'schtasks /Run /TN StartMWB' | Out-Null
    Start-Sleep -Seconds 3
}
finally {
    Remote 'schtasks /Delete /TN StartMWB /F' | Out-Null
}

Log 'Waiting for peers to connect...'
Start-Sleep -Seconds 12

# --- Verification -----------------------------------------------------------
Log 'Local 15100/15101 sockets:'
(netstat -ano | Select-String '15100|15101') | ForEach-Object { Log "  $($_.Line.Trim())" }

Log 'ERAZER 15100/15101 sockets:'
(Remote 'netstat -ano | findstr 15100 15101') | ForEach-Object { Log "  $($_.ToString().Trim())" }

$established = (netstat -ano | Select-String '15101' | Select-String 'ESTABLISHED').Count
if ($established -gt 0) {
    Log "RESULT: MWB link established ($established session(s) on port 15101)."
}
else {
    Log 'RESULT: no established MWB session detected. Re-run once or check the apps manually.'
}
Log '=== Reset-MWB finished ==='
