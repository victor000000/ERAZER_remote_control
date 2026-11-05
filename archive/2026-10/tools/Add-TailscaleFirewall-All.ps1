$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

foreach ($r in @(
    @{ Name = 'Tailscale UDP 41641 In'; Dir = 'Inbound'; PortKey = 'LocalPort' },
    @{ Name = 'Tailscale UDP 41641 Out'; Dir = 'Outbound'; PortKey = 'RemotePort' }
)) {
    $existing = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
    if ($existing) {
        $existing | Set-NetFirewallRule -Enabled True -Profile Any -Action Allow -ErrorAction SilentlyContinue
        Write-Output ('updated: ' + $r.Name)
    } else {
        $params = @{ DisplayName = $r.Name; Direction = $r.Dir; Action = 'Allow'; Protocol = 'UDP'; Profile = 'Any' }
        $params[$r.PortKey] = 41641
        New-NetFirewallRule @params | Out-Null
        Write-Output ('added: ' + $r.Name)
    }
}

Get-NetFirewallRule -DisplayName 'Tailscale*' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action, Profile |
    Format-Table -AutoSize | Out-String | Write-Output
