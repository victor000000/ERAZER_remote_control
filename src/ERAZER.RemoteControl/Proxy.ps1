function Get-ProxyDecision {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$Ssid,
        [string]$Gateway,
        [Parameter(Mandatory)][hashtable]$ProxyMap,
        [Nullable[bool]]$ProbeSucceeded,
        [string]$PreviousEndpoint = '',
        [ValidateRange(0, 999)][int]$Failures = 0,
        [ValidateRange(0, 999)][int]$UnknownObservations = 0,
        [ValidateRange(1, 99)][int]$FailureThreshold = 3,
        [ValidateRange(1, 99)][int]$UnknownThreshold = 3,
        [string]$InterfaceAlias = ''
    )
    $action = 'Disable'; $reason = 'Unrecognized network'; $server = ''; $endpoint = ''; $nextFailures = 0; $unknown = 0
    $key = @($ProxyMap.Keys | Where-Object { [string]::Equals([string]$_, $Ssid, [StringComparison]::Ordinal) })
    if (-not $Ssid) {
        $unknown = [math]::Min($UnknownThreshold, $UnknownObservations + 1)
        if ($InterfaceAlias -and $InterfaceAlias -notmatch 'WLAN|Wi-?Fi|Wireless') { $reason = 'No Wi-Fi SSID; route is not wireless' }
        elseif ($unknown -ge $UnknownThreshold) { $reason = 'Network observation unavailable for too many checks' }
        else { $action = 'Hold'; $reason = 'Waiting for network observation' }
    } elseif ($key.Count -eq 1) {
        $server = [string]$ProxyMap[$key[0]]
        if ($server.Contains('<gateway>')) {
            $ip = $null
            if (-not [Net.IPAddress]::TryParse($Gateway, [ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { $server = '' }
            else { $server = $server.Replace('<gateway>', $Gateway) }
        }
        $endpoint = $Ssid + '|' + $server
        if (-not $server) { $reason = 'No valid proxy endpoint for network' }
        elseif ($null -eq $ProbeSucceeded) { $action = 'Hold'; $reason = 'Proxy probe not available' }
        elseif ($ProbeSucceeded) { $action = 'Enable'; $reason = 'Proxy is reachable' }
        else {
            $nextFailures = 1
            if ($PreviousEndpoint -ceq $endpoint) { $nextFailures = [math]::Min($FailureThreshold, $Failures + 1) }
            if ($nextFailures -lt $FailureThreshold) { $action = 'Hold'; $reason = 'Transient proxy probe failure' }
            else { $reason = 'Proxy failure threshold reached' }
        }
    }
    return [pscustomobject]@{ Action = $action; Server = $server; Endpoint = $endpoint; Failures = $nextFailures; UnknownObservations = $unknown; Reason = $reason }
}

function Set-IniSectionValue {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Content, [Parameter(Mandatory)][string]$Section, [Parameter(Mandatory)][string]$Name, [AllowEmptyString()][string]$Value)
    if ($Section -match '[\[\]\r\n]' -or $Name -match '[=\r\n]' -or $Value -match '[\r\n]') { throw 'Invalid INI section, key or value.' }
    $newline = "`n"
    if ($Content.Contains("`r`n")) { $newline = "`r`n" }
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in [regex]::Split($Content, '\r?\n')) { $lines.Add($line) }
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[([^\]]+)\]\s*$') {
            if ($start -ge 0) { $end = $i; break }
            if ($Matches[1] -ieq $Section) { $start = $i }
        }
    }
    if ($start -lt 0) {
        while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        $lines.Add('[' + $Section + ']'); $lines.Add($Name + '=' + $Value); $lines.Add('')
    } else {
        $found = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match ('^\s*' + [regex]::Escape($Name) + '\s*=')) { $lines[$i] = $Name + '=' + $Value; $found = $true }
        }
        if (-not $found) { $lines.Insert($start + 1, $Name + '=' + $Value) }
    }
    return ($lines -join $newline)
}

function Test-ProxyEndpoint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Server, [ValidateRange(1, 30000)][int]$TimeoutMilliseconds = 700)
    $match = [regex]::Match($Server, '^(?<host>[A-Za-z0-9.-]+):(?<port>\d{1,5})$')
    if (-not $match.Success -or [int]$match.Groups['port'].Value -lt 1 -or [int]$match.Groups['port'].Value -gt 65535) { return $false }
    $client = [Net.Sockets.TcpClient]::new()
    $wait = $null
    try {
        $connection = $client.BeginConnect($match.Groups['host'].Value, [int]$match.Groups['port'].Value, $null, $null)
        $wait = $connection.AsyncWaitHandle
        if (-not $wait.WaitOne($TimeoutMilliseconds)) { return $false }
        $client.EndConnect($connection)
        return $true
    } catch { return $false }
    finally { $client.Dispose(); if ($wait) { $wait.Dispose() } }
}

function Set-WinInetProxy {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][bool]$On, [string]$Server)
    if ($On -and [string]::IsNullOrWhiteSpace($Server)) { throw 'A proxy server is required to enable the proxy.' }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $old = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    $desired = @{ ProxyEnable = [int]$On }
    if ($On) { $desired.ProxyServer = $Server; $desired.ProxyOverride = '<local>;192.168.*;10.*;169.254.*' }
    $changes = @($desired.Keys | Where-Object { -not $old.PSObject.Properties[$_] -or $old.$_ -ne $desired[$_] })
    if ($changes.Count -eq 0 -or -not $PSCmdlet.ShouldProcess('Current user WinINET proxy', 'Apply verified proxy decision')) { return $false }
    $written = [Collections.Generic.List[string]]::new()
    try {
        foreach ($name in @('ProxyServer', 'ProxyOverride', 'ProxyEnable')) {
            if ($changes -notcontains $name) { continue }
            $type = 'String'; if ($name -eq 'ProxyEnable') { $type = 'DWord' }
            Set-ItemProperty -LiteralPath $key -Name $name -Value $desired[$name] -Type $type -ErrorAction Stop
            $written.Add($name)
        }
    } catch {
        foreach ($name in $written) {
            try {
                if ($old.PSObject.Properties[$name]) { Set-ItemProperty -LiteralPath $key -Name $name -Value $old.$name -ErrorAction Stop }
                else { Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop }
            } catch { Write-Warning "Proxy rollback could not restore $name." }
        }
        throw
    }
    if (-not ('ERAZER.WinInet' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace ERAZER { public static class WinInet {
    [DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr handle, int option, IntPtr buffer, int length);
} }
'@
    }
    [void][ERAZER.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][ERAZER.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
    return $true
}

function Set-WinHttpProxy {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][bool]$On, [string]$Server)
    if ($On -and [string]::IsNullOrWhiteSpace($Server)) { throw 'A proxy server is required.' }
    if (-not $PSCmdlet.ShouldProcess('Machine WinHTTP proxy', 'Apply proxy decision')) { return }
    if ($On) { $output = & netsh.exe winhttp set proxy "proxy-server=$Server" 'bypass-list=<local>;192.168.*;10.*;169.254.*' 2>&1 }
    else { $output = & netsh.exe winhttp reset proxy 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "WinHTTP update failed (exit $LASTEXITCODE)." }
    Write-Verbose ($output -join ' ')
}
