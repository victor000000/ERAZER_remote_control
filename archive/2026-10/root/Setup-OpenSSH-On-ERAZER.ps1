#Requires -RunAsAdministrator
<#
  Installs the official Win32-OpenSSH package on the ERAZER and configures
  key-only access for the controlling PC.

  Why not Add-WindowsCapability: the Windows Update source was slow and
  unreliable on this network. This uses the signed MSI from the official
  PowerShell/Win32-OpenSSH release, fetched through a GitHub mirror and
  verified against a pinned SHA-256.

  Run ON the ERAZER in an elevated PowerShell.
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$hash = 'ddec9c53864280759cf9f74791cefd387100e3946aa849a1c138a4ed1b96b7d9'
$url = 'https://gh-proxy.com/https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64-v10.0.0.0.msi'
$msi = Join-Path $env:TEMP 'OpenSSH-Win64.msi'

Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -TimeoutSec 60
if ((Get-FileHash $msi -Algorithm SHA256).Hash -ne $hash) {
    throw 'Downloaded MSI failed the SHA-256 check; refusing to install.'
}

Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
Start-Sleep -Seconds 2

Set-Service sshd -StartupType Automatic
Start-Service sshd -ErrorAction SilentlyContinue

if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

# Public key of the controlling PC (claude@StupicVicPC).
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACBKTaAof3JNeT0ILOE7EW1myLhyyCnDHHhgB4XiR6X claude@StupicVicPC'

# Administrator account: sshd reads administrators_authorized_keys.
$adminKeys = 'C:\ProgramData\ssh\administrators_authorized_keys'
New-Item -ItemType Directory -Force -Path (Split-Path $adminKeys) | Out-Null
if (-not (Test-Path $adminKeys) -or -not (Select-String -Path $adminKeys -SimpleMatch $key -Quiet)) {
    Add-Content -Path $adminKeys -Value $key
}
icacls $adminKeys /inheritance:r | Out-Null
icacls $adminKeys /grant '*S-1-5-32-544:F' '*S-1-5-18:F' | Out-Null

# Also write the per-user key in case the account is not an administrator.
$userKeys = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
New-Item -ItemType Directory -Force -Path (Split-Path $userKeys) | Out-Null
if (-not (Test-Path $userKeys) -or -not (Select-String -Path $userKeys -SimpleMatch $key -Quiet)) {
    Add-Content -Path $userKeys -Value $key
}

$svc = Get-Service sshd
Write-Host "sshd        : $($svc.Status) / $($svc.StartType)"
Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue |
    Format-Table LocalAddress, LocalPort -AutoSize
Write-Host "admin keys  : $(Test-Path $adminKeys)"
Write-Host "user keys   : $(Test-Path $userKeys)"
