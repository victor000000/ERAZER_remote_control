# Opens one inbound TCP port so the ERAZER can download the RustDesk
# installer from this PC over the hotspot LAN.
param([int]$Port = 8000)
$ErrorActionPreference = 'Stop'
$name = "RustDesk LAN transfer $Port"
if (-not (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol TCP `
        -LocalPort $Port -Action Allow -Profile Any | Out-Null
}
"firewall rule ready: $name"
