$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

Write-Output '=== FIREWALL RULES ==='
foreach ($r in @(
    @{ Name = 'Tailscale UDP 41641 In'; Dir = 'Inbound'; Port = 'LocalPort' },
    @{ Name = 'Tailscale UDP 41641 Out'; Dir = 'Outbound'; Port = 'RemotePort' }
)) {
    $existing = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        $params = @{
            DisplayName = $r.Name
            Direction = $r.Dir
            Action = 'Allow'
            Protocol = 'UDP'
            Profile = 'Any'
        }
        $params[$r.Port] = 41641
        New-NetFirewallRule @params | Out-Null
        Write-Output ('added: ' + $r.Name)
    } else { Write-Output ('exists: ' + $r.Name) }
}
Get-NetFirewallRule -DisplayName 'Tailscale UDP 41641*' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize | Out-String | Write-Output

Write-Output '=== NETCHECK ==='
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    (& $ts netcheck 2>&1) | Select-Object -First 25 | ForEach-Object { Write-Output $_ }
    Write-Output '=== PING ==='
    (& $ts ping -c 3 100.105.143.1 2>&1) | ForEach-Object { Write-Output $_ }
}
