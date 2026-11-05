$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '=== TAILSCALE FIREWALL RULES (PC) ==='
$rules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Tailscale' }
if ($rules) {
    $rules | Select-Object DisplayName, Enabled, Direction, Action, Profile |
        Format-Table -AutoSize | Out-String | Write-Output
} else { W 'NO Tailscale firewall rules found' }

W '=== AP INTERFACE PROFILE ==='
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceAlias, NetworkCategory |
    Format-Table -AutoSize | Out-String | Write-Output

W '=== TAILSCALE PEER ENDPOINTS ==='
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) {
    $json = & $ts status --json 2>$null | Out-String
    try {
        $j = $json | ConvertFrom-Json
        foreach ($k in $j.Peer.PSObject.Properties.Name) {
            $p = $j.Peer.$k
            W ('peer: ' + $p.HostName + ' online=' + $p.Online)
            W ('  endpoints: ' + (($p.Endpoints) -join ', '))
            W ('  relay: ' + $p.Relay + ' curAddr: ' + $p.CurAddr)
        }
    } catch { W ('json parse failed: ' + $_.Exception.Message) }
    W '=== PING ==='
    (& $ts ping -c 3 100.105.143.1 2>&1) | ForEach-Object { W $_ }
}

W '=== UDP REACHABILITY TEST (PC listens, ERAZER sends) ==='
$listener = New-Object System.Net.Sockets.UdpClient(41642)
$listener.Client.ReceiveTimeout = 8000
W 'listener on UDP 41642 started (8s)'
try {
    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    $data = $listener.Receive([ref]$remote)
    W ('received UDP from ' + $remote + ' bytes=' + $data.Length)
} catch { W ('no UDP received: ' + $_.Exception.Message) }
$listener.Close()
