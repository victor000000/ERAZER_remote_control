param(
    [switch]$Watch,
    [switch]$DryRun,
    [string]$SimulateSsid,
    [string]$SimulateGateway,
    [int]$ProbeTimeoutMs = 700,
    [switch]$SkipMT5
)

$script:BaseDir = $PSScriptRoot
if (-not $script:BaseDir) { $script:BaseDir = 'C:\Users\Vic\Desktop' }
$script:LogPath = Join-Path $script:BaseDir 'proxy-watch.log'
$script:ProxySsids = @('HypoMux', 'MiFi-1A8F', 'MiFi706425-5G')
$script:FixedProxyServers = @{ 'MiFi-1A8F' = '192.168.1.100:7897'; 'MiFi706425-5G' = '192.168.0.2:7897' }
$script:ProxyPort = 7897
$script:Mt5Dir = 'C:\MetaTrader 5 IC Markets Global'
$script:Mt5Ini = Join-Path $script:Mt5Dir 'Config\common.ini'
$script:Failures = 0
$script:Cycle = 0
$script:LastPower = $null
$script:WinHttpState = $null
$script:IsAdmin = $false

try {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent()
    $script:IsAdmin = ([Security.Principal.WindowsPrincipal]$sid).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

function Log([string]$m) {
    try {
        if ((Test-Path -LiteralPath $script:LogPath) -and
            (Get-Item -LiteralPath $script:LogPath).Length -gt 1048576) {
            Move-Item -LiteralPath $script:LogPath -Destination ($script:LogPath + '.old') -Force
        }
        "$(Get-Date -Format o) $m" | Add-Content -LiteralPath $script:LogPath -Encoding UTF8
    } catch { }
}

function Get-Ssid {
    if ($SimulateSsid) { return $SimulateSsid }
    $out = & netsh wlan show interfaces 2>$null
    foreach ($line in $out) {
        if ($line -match '^\s*SSID\s*:\s*(.+)$') { return $Matches[1].Trim() }
    }
    return ''
}

function Get-RouteInfo {
    if ($SimulateGateway) {
        return [pscustomobject]@{ NextHop = $SimulateGateway; InterfaceAlias = 'WLAN' }
    }
    $all = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric)
    if ($all.Count -eq 0) { return $null }
    $wifi = $all | Where-Object { $_.InterfaceAlias -match 'WLAN|Wi-?Fi|Wireless' } |
        Select-Object -First 1
    if ($wifi) { return $wifi }
    return $all[0]
}

function Test-ProxyAlive([string]$server) {
    if (-not $server) { return $false }
    $parts = $server.Split(':')
    if ($parts.Count -ne 2) { return $false }
    $client = New-Object Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($parts[0], [int]$parts[1], $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($ProbeTimeoutMs)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Refresh-WinInet {
    if (-not ('ERAZER.WinInet' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ERAZER {
    public static class WinInet {
        [DllImport("wininet.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool InternetSetOption(IntPtr hInternet, int dwOption,
            IntPtr lpBuffer, int dwBufferLength);
    }
}
'@
    }
    [void][ERAZER.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][ERAZER.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
}

function Set-SystemProxy([bool]$on, [string]$server) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $cur = Get-ItemProperty -Path $key -ErrorAction Stop
    $curEnable = 0
    if ($null -ne $cur.ProxyEnable) { $curEnable = [int]$cur.ProxyEnable }
    $curServer = [string]$cur.ProxyServer
    $bypass = '<local>;192.168.*;10.*;169.254.*'
    $changed = $false

    if ($on) {
        if ($curEnable -ne 1) {
            Set-ItemProperty -Path $key -Name ProxyEnable -Value 1 -Type DWord
            $changed = $true
        }
        if ($curServer -ne $server) {
            Set-ItemProperty -Path $key -Name ProxyServer -Value $server -Type String
            $changed = $true
        }
        if ([string]$cur.ProxyOverride -ne $bypass) {
            Set-ItemProperty -Path $key -Name ProxyOverride -Value $bypass -Type String
            $changed = $true
        }
    } else {
        if ($curEnable -ne 0) {
            Set-ItemProperty -Path $key -Name ProxyEnable -Value 0 -Type DWord
            $changed = $true
        }
    }

    if ($changed) {
        try { Refresh-WinInet } catch { Log "WinINET refresh failed: $($_.Exception.Message)" }
    }
    return $changed
}

function Set-WinHttpProxy([bool]$on, [string]$server) {
    $target = 'off'
    if ($on) { $target = $server }

    if (-not $script:IsAdmin) {
        if ($script:WinHttpState -ne 'skipped') {
            Log 'WinHTTP not updated: process is not elevated'
            $script:WinHttpState = 'skipped'
        }
        return
    }
    if ($script:WinHttpState -eq $target) { return }

    $bypass = '<local>;192.168.*;10.*;169.254.*'
    $output = $null
    if ($on) {
        $output = & netsh winhttp set proxy "proxy-server=$server" "bypass-list=$bypass" 2>&1
    } else {
        $output = & netsh winhttp reset proxy 2>&1
    }
    if ($LASTEXITCODE -eq 0) {
        $script:WinHttpState = $target
        if ($on) { Log "WinHTTP proxy set to $server" }
        else { Log 'WinHTTP proxy reset to direct' }
    } else {
        $text = ($output | Out-String).Trim()
        Log "WinHTTP update failed (exit $LASTEXITCODE): $text"
        $script:WinHttpState = $null
    }
}

function Set-IniValue([string]$text, [string]$name, [string]$value) {
    $pattern = '(?m)^' + [regex]::Escape($name) + '=.*$'
    if ([regex]::IsMatch($text, $pattern)) {
        return [regex]::Replace($text, $pattern, "$name=$value")
    }
    if ([regex]::IsMatch($text, '(?m)^\[Common\]\s*$')) {
        $insert = "[Common]`r`n$name=$value"
        return [regex]::Replace($text, '(?m)^\[Common\]\s*$', $insert, 1)
    }
    return $text.TrimEnd() + "`r`n$name=$value`r`n"
}

function Get-Mt5Content([string]$text, [bool]$on, [string]$server) {
    $new = $text
    if ($on) {
        $new = Set-IniValue $new 'ProxyEnable' '1'
        $new = Set-IniValue $new 'ProxyType' '2'
        $new = Set-IniValue $new 'ProxyAddress' $server
        $new = Set-IniValue $new 'ProxyAuth' ''
    } else {
        $new = Set-IniValue $new 'ProxyEnable' '0'
    }
    return $new
}

function Stop-MT5([int]$timeoutSec = 15) {
    $procs = @(Get-Process terminal64 -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return $true }
    foreach ($p in $procs) {
        try { [void]$p.CloseMainWindow() } catch { }
    }
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (-not (Get-Process terminal64 -ErrorAction SilentlyContinue)) { return $true }
    }
    return $false
}

function Start-MT5 {
    $exe = Join-Path $script:Mt5Dir 'terminal64.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Log "MT5 exe not found: $exe"
        return
    }
    Start-Process -FilePath $exe -ArgumentList '/portable' -WorkingDirectory $script:Mt5Dir
    Log 'MT5 started'
}

function Update-MT5Proxy([bool]$on, [string]$server) {
    if (-not (Test-Path -LiteralPath $script:Mt5Ini)) { return $false }
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    $old = [IO.File]::ReadAllText($script:Mt5Ini, $latin1)
    $new = Get-Mt5Content $old $on $server
    if ($new -eq $old) { return $false }

    $running = [bool](Get-Process terminal64 -ErrorAction SilentlyContinue)
    if ($running) {
        if (-not (Stop-MT5)) {
            Log 'MT5 did not close; will retry proxy config update next cycle'
            return $false
        }
    }
    [IO.File]::WriteAllText($script:Mt5Ini, $new, $latin1)
    Log "MT5 proxy config updated (on=$on server='$server')"
    if ($running) { Start-MT5 }
    return $true
}

function Sync-Once {
    $script:Cycle++

    $ssid = Get-Ssid
    $route = Get-RouteInfo
    $gw = ''
    $alias = ''
    if ($route) {
        $gw = [string]$route.NextHop
        $alias = [string]$route.InterfaceAlias
    }
    $server = ''
    if ($gw) { $server = "${gw}:$($script:ProxyPort)" }
    $isProxySsid = [bool]($ssid -and ($script:ProxySsids -contains $ssid))
    if ($isProxySsid -and $script:FixedProxyServers.ContainsKey($ssid)) {
        $server = $script:FixedProxyServers[$ssid]
    }

    $decide = $true
    $wantOn = $false
    $note = ''

    if ($isProxySsid) {
        if (-not $server) {
            $wantOn = $false
            $note = "ssid=$ssid but no proxy server; proxy off"
        } elseif (Test-ProxyAlive $server) {
            $wantOn = $true
            $script:Failures = 0
            $note = "proxy reachable at $server"
        } else {
            $script:Failures++
            if ($script:Failures -ge 3) {
                $wantOn = $false
                $note = "proxy unreachable at $server after $($script:Failures) checks; proxy off"
            } else {
                $decide = $false
                $note = "proxy probe failed ($($script:Failures)/3); keeping current state"
            }
        }
    } elseif ($ssid) {
        $wantOn = $false
        $script:Failures = 0
        $note = "ssid='$ssid' is not a proxy SSID; proxy off"
    } else {
        if ($route -and $alias -notmatch 'WLAN|Wi-?Fi|Wireless') {
            $wantOn = $false
            $note = "no SSID, route via '$alias'; proxy off"
        } else {
            $decide = $false
            $note = 'no SSID yet; keeping current state'
        }
        $script:Failures = 0
    }

    if (-not $decide) {
        if ($DryRun -or ($script:Cycle % 20 -eq 1)) {
            Log "hold: $note (ssid='$ssid' gw='$gw')"
        }
        return
    }

    if ($DryRun) {
        Log "dry-run: wantOn=$wantOn server='$server' ($note)"
        return
    }

    $sysChanged = Set-SystemProxy $wantOn $server
    Set-WinHttpProxy $wantOn $server
    $mt5Changed = $false
    if (-not $SkipMT5) {
        $mt5Changed = Update-MT5Proxy $wantOn $server
    }

    if ($script:LastPower -ne $wantOn) {
        Log "proxy power=$wantOn server='$server' | $note | wininetChanged=$sysChanged mt5Changed=$mt5Changed skipMT5=$SkipMT5"
        $script:LastPower = $wantOn
    } elseif ($script:Cycle % 20 -eq 1) {
        Log "heartbeat: power=$wantOn server='$server' | $note"
    }
}

if ($Watch) {
    $mutex = $null
    try {
        $mutex = New-Object System.Threading.Mutex($false, 'Local\ERAZER_ProxyWatcher')
        $owned = $false
        try { $owned = $mutex.WaitOne(0) }
        catch [System.Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) {
            Log 'another proxy watcher is already running; exit'
            exit 0
        }
    } catch {
        Log "mutex setup failed: $($_.Exception.Message)"
    }

    Log "=== proxy watcher v3 started (admin=$($script:IsAdmin) skipMT5=$SkipMT5 pid=$PID) ==="
    while ($true) {
        try { Sync-Once } catch { Log "error: $($_.Exception.Message)" }
        Start-Sleep -Seconds 30
    }
} else {
    Log "=== proxy sync v2 (admin=$($script:IsAdmin) dryRun=$DryRun) ==="
    Sync-Once
}
