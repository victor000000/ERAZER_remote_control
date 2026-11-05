param([string]$Adapter = 'WLAN')
# Sets TcpAckFrequency=1 and TCPNoDelay=1 for the given adapter's IPv4
# interface (reduces delayed-ACK/Nagle latency for small packets).
# Run elevated. Logs to %TEMP%\Set-TcpLowLatency.log.
$ErrorActionPreference = 'Stop'
$nic = Get-NetAdapter -Name $Adapter -ErrorAction Stop
$guid = $nic.InterfaceGuid
$path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
Set-ItemProperty -Path $path -Name TcpAckFrequency -Value 1 -Type DWord
Set-ItemProperty -Path $path -Name TCPNoDelay -Value 1 -Type DWord
$log = Join-Path $env:TEMP 'Set-TcpLowLatency.log'
"Adapter: $Adapter  GUID: $guid" | Out-File -LiteralPath $log -Encoding utf8
Get-ItemProperty -Path $path |
    Select-Object TcpAckFrequency, TCPNoDelay |
    Format-List | Out-File -LiteralPath $log -Append -Encoding utf8
