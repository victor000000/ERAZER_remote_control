#Requires -RunAsAdministrator
<#
  Run this ON ERAZER-6JMHAKCD, in an elevated PowerShell
  (Win+X -> Terminal (Admin), paste this whole file, press Enter).

  It detects the Windows edition and sets up full remote control:

    - Pro / Enterprise / Education:
        Enables the built-in Remote Desktop host (RDP), opens the
        firewall rules, requires Network Level Authentication.

    - Home (or anything else):
        Remote Desktop host is not available on Home. Installs
        RustDesk instead and prints its ID and an unattended password.

  Re-running the script is safe.
#>

$ErrorActionPreference = 'Stop'

$ver = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$edition = $ver.EditionID

Write-Host ''
Write-Host "Computer : $env:COMPUTERNAME"
Write-Host "Edition  : $edition ($($ver.DisplayVersion), build $($ver.CurrentBuild))"
Write-Host ''

if ($edition -match 'Professional|Enterprise|Education') {

    Write-Host 'Enabling the Remote Desktop host (RDP)...'

    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
        -Name fDenyTSConnections -Value 0
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
        -Name UserAuthentication -Value 1
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752'

    # Allow the current account to sign in over RDP (admins already can;
    # harmless if the account is a member).
    try {
        Add-LocalGroupMember -SID 'S-1-5-32-555' -Member $env:USERNAME -ErrorAction Stop
    } catch { }

    $account = Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue
    $ips = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet'
        }).IPAddress

    Write-Host ''
    Write-Host 'RDP is enabled.'
    Write-Host ''
    Write-Host "Account  : $env:USERNAME"
    if ($account) {
        Write-Host "Password set : $($account.PasswordLastSet)"
    }
    Write-Host "IPv4     : $($ips -join ', ')"
    Write-Host ''
    Write-Host "From StupicVicPC run:  mstsc /v:<one of the IPv4 addresses above>"
    Write-Host ''
    Write-Host 'Notes:'
    Write-Host '  - RDP sign-in needs the account PASSWORD (a PIN does not work).'
    Write-Host '  - If the account is a Microsoft account, use its online password.'
    Write-Host '  - While connected, the physical screen shows the lock screen;'
    Write-Host '    that is normal for RDP.'
}
else {

    Write-Host 'This edition has no Remote Desktop host (Home edition).'
    Write-Host 'Installing RustDesk instead...'
    Write-Host ''

    winget install --id RustDesk.RustDesk -e --silent `
        --accept-source-agreements --accept-package-agreements

    $exe = @(
        "$env:ProgramFiles\RustDesk\rustdesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe",
        "$env:LOCALAPPDATA\Programs\RustDesk\rustdesk.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $exe) {
        Write-Host ''
        Write-Host 'RustDesk was installed but the executable was not found.'
        Write-Host 'Open RustDesk from the Start menu, set a permanent password in'
        Write-Host 'Settings > Security, and note the ID shown on the main screen.'
        return
    }

    # Safe-to-paste alphabet (no lookalikes, no shell metacharacters).
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $password = -join (1..16 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

    & $exe --password $password
    Start-Sleep -Seconds 2
    $id = (& $exe --get-id 2>$null | Select-Object -First 1)

    Write-Host ''
    Write-Host "RustDesk ID     : $id"
    Write-Host "Unattended pass : $password"
    Write-Host ''
    Write-Host 'Next steps:'
    Write-Host '  1. In RustDesk choose Settings > Security and enable'
    Write-Host '     "Enable direct IP access" (needed for fast LAN connections).'
    Write-Host '  2. Install RustDesk on StupicVicPC and connect using the ID'
    Write-Host '     above (or 192.168.1.200 with direct IP access enabled),'
    Write-Host '     then enter the unattended password.'
}
