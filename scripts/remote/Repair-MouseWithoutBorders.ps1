[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$PeerName,
    [Parameter(Mandatory)][System.Net.IPAddress]$PeerAddress,
    [System.Net.IPAddress]$FallbackPeerAddress,
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = 'C:\ProgramData\ERAZER-Tools\MouseWithoutBorders'
$taskName = 'ERAZER-MouseWithoutBorders-Reconnect'
$serviceName = 'MouseWithoutBordersSvc'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Administrator permissions are required to repair hosts and configure the reconnect service.' }
if ($PeerAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'An IPv4 LAN address is required.' }
function Write-RepairLog([string]$Message) {
    $log = Join-Path $root 'repair.log'
    Add-Content $log ((Get-Date -Format o) + ' ' + $Message)
    if ((Get-Item $log).Length -gt 131072) { $tail = @(Get-Content $log -Tail 100); Set-Content $log $tail }
}
function Test-PeerPort([System.Net.IPAddress]$Address) {
    $client = New-Object Net.Sockets.TcpClient
    try { $pending = $client.ConnectAsync($Address.ToString(),15101); return ($pending.Wait(2000) -and $client.Connected) } catch { return $false } finally { $client.Dispose() }
}
function Update-PeerHosts([System.Net.IPAddress]$Address) {
    $hosts = Join-Path $env:windir 'System32\drivers\etc\hosts'
    $oldAddresses = @([Net.Dns]::GetHostAddresses($PeerName).IPAddressToString)
    if ($oldAddresses.Count -eq 1 -and $oldAddresses[0] -eq $Address.ToString()) { return }
    $backup = Join-Path $root ('hosts-before-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.bak')
    Copy-Item $hosts $backup
    $before = [IO.File]::ReadAllLines($hosts)
    $after = foreach ($line in $before) {
        $parts = $line -split '#',2
        $tokens = @($parts[0].Trim() -split '\s+' | Where-Object { $_ })
        if ($tokens.Count -ge 2 -and @($tokens | Select-Object -Skip 1 | Where-Object {$_ -ieq $PeerName}).Count) {
            $remaining = @($tokens | Select-Object -Skip 1 | Where-Object {$_ -ine $PeerName})
            if ($remaining.Count) { $tokens[0] + "`t" + ($remaining -join ' ') + $(if($parts.Count -gt 1){' #'+$parts[1]}) }
            elseif ($parts.Count -gt 1) { '#'+$parts[1] }
        } else { $line }
    }
    $after += $Address.ToString() + "`t" + $PeerName + ' # Mouse Without Borders LAN'
    [IO.File]::WriteAllLines($hosts,[string[]]$after,[Text.UTF8Encoding]::new($false))
    Clear-DnsClientCache
    Write-RepairLog "Updated peer address: $PeerName/$Address; backup=$backup"
}
if ($Install) {
    New-Item $root -ItemType Directory -Force | Out-Null
    # The SYSTEM task must execute only an administrator-controlled copy.
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl $root $acl
    $script = Join-Path $root 'Repair-MouseWithoutBorders.ps1'
    if ($PSCommandPath -ne $script) { Copy-Item $PSCommandPath $script -Force }
    Set-Service $serviceName -StartupType Automatic
    $ps = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '" -PeerName "' + $PeerName + '" -PeerAddress "' + $PeerAddress + '"'
    if ($FallbackPeerAddress) { $arguments += ' -FallbackPeerAddress "' + $FallbackPeerAddress + '"' }
    $action = New-ScheduledTaskAction -Execute $ps -Argument $arguments
    $triggers = @((New-ScheduledTaskTrigger -AtStartup),(New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 2)))
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
    Write-RepairLog "Installed automatic reconnect; peer=$PeerName/$PeerAddress; fallback=$FallbackPeerAddress"
}
$candidates = @($PeerAddress.ToString())
if ($FallbackPeerAddress) { $candidates += $FallbackPeerAddress.ToString() }
# A healthy MWB connection needs no restart or input disruption.
$connections = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object {
    ($_.LocalPort -in 15100,15101 -or $_.RemotePort -in 15100,15101) -and $_.RemoteAddress.Replace('::ffff:','') -in $candidates
})
if ($connections.Count) {
    Update-PeerHosts ([Net.IPAddress]::Parse($connections[0].RemoteAddress.Replace('::ffff:','')))
    Remove-Item (Join-Path $root 'disconnected-since.txt') -ErrorAction SilentlyContinue
    Write-Output 'Peer connection established; no restart needed.'
    exit 0
}
# Offline peers are not a reason to restart the local app repeatedly.
$reachable = $null
foreach ($candidate in $candidates) { if (Test-PeerPort ([Net.IPAddress]::Parse($candidate))) { $reachable = [Net.IPAddress]::Parse($candidate); break } }
if (-not $reachable) { Write-Output 'Peer unavailable; waiting for the next scheduled check.'; exit 0 }
$PeerAddress = $reachable
Update-PeerHosts $PeerAddress
$pendingFile = Join-Path $root 'disconnected-since.txt'
if (-not $Install) {
    if (-not (Test-Path $pendingFile)) { Set-Content $pendingFile (Get-Date).ToUniversalTime().ToString('o'); exit 0 }
    if (((Get-Date).ToUniversalTime() - [datetime]::Parse((Get-Content $pendingFile -Raw))).TotalSeconds -lt 90) { exit 0 }
}
$lastFile = Join-Path $root 'last-reconnect.txt'
if ((Test-Path $lastFile) -and -not $Install) {
    if (((Get-Date).ToUniversalTime() - [datetime]::Parse((Get-Content $lastFile -Raw))).TotalMinutes -lt 5) { exit 0 }
}
Stop-Service $serviceName -ErrorAction SilentlyContinue
Get-Process MouseWithoutBorders,MouseWithoutBordersHelper -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Service $serviceName
Set-Content $lastFile (Get-Date).ToUniversalTime().ToString('o')
Remove-Item $pendingFile -ErrorAction SilentlyContinue
Write-RepairLog "Restarted Mouse Without Borders to reconnect to $PeerName/$PeerAddress"
Write-Output 'Mouse Without Borders reconnect initiated.'
