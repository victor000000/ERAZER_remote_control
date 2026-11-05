[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Watch, [switch]$DryRun, [switch]$SkipMT5, [switch]$UpdateMT5,
    [string]$SimulateSsid, [string]$SimulateGateway, [Nullable[bool]]$SimulateProxyAvailable,
    [ValidateRange(1,30000)][int]$ProbeTimeoutMs = 700,
    [ValidateRange(1,3600)][int]$IntervalSeconds = 30,
    [string]$ConfigPath, [string]$LocalConfigPath
)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if ($UpdateMT5 -and $SkipMT5) { throw 'Use either -UpdateMT5 or -SkipMT5, not both.' }
$simulation = $PSBoundParameters.ContainsKey('SimulateSsid') -or $PSBoundParameters.ContainsKey('SimulateGateway') -or $PSBoundParameters.ContainsKey('SimulateProxyAvailable')
if ($simulation -and -not ($DryRun -or $WhatIfPreference)) { throw 'Simulation requires -DryRun or -WhatIf.' }
if (-not ($DryRun -or $WhatIfPreference) -and $env:COMPUTERNAME -ine $config.Target.HostName) { throw 'Proxy watcher must run on the configured target; use -DryRun on the controller.' }
$previous = ''; $failures = 0; $unknown = 0
$mutex = $null; $owned = $false
try {
    if ($Watch -and -not ($DryRun -or $WhatIfPreference)) {
        $mutex = [Threading.Mutex]::new($false, 'Local\ERAZER_ProxyWatcher')
        try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { throw 'Another proxy watcher is already running.' }
    }
    do {
        try {
        $ssid = ''; $gateway = ''; $alias = ''
        if ($simulation) { $ssid = $SimulateSsid; $gateway = $SimulateGateway; $alias = 'WLAN' }
        else {
            $output = & netsh.exe wlan show interfaces 2>&1
            if ($LASTEXITCODE -eq 0) {
                foreach ($line in $output) {
                    if ($line -match '^\s*SSID\s*:\s(.+)$') { $ssid = $Matches[1]; break }
                }
            }
            $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object RouteMetric)
            $route = $routes | Where-Object { $_.InterfaceAlias -match 'WLAN|Wi-?Fi|Wireless' } | Select-Object -First 1
            if (-not $route) { $route = $routes | Select-Object -First 1 }
            if ($route) { $gateway = $route.NextHop; $alias = $route.InterfaceAlias }
        }
        $parameters = @{ Ssid=$ssid; Gateway=$gateway; ProxyMap=$config.Proxy.Servers; PreviousEndpoint=$previous; Failures=$failures; UnknownObservations=$unknown; FailureThreshold=$config.Proxy.FailureThreshold; UnknownThreshold=$config.Proxy.UnknownThreshold; InterfaceAlias=$alias }
        $candidate = Get-ProxyDecision @parameters
        $probe = $null
        if ($simulation) { $probe = $SimulateProxyAvailable }
        elseif ($candidate.Server) { $probe = Test-ProxyEndpoint -Server $candidate.Server -TimeoutMilliseconds $ProbeTimeoutMs }
        $decision = Get-ProxyDecision @parameters -ProbeSucceeded $probe
        $previous = $decision.Endpoint; $failures = $decision.Failures; $unknown = $decision.UnknownObservations
        $decision
        if ($decision.Action -ne 'Hold' -and -not $DryRun -and $PSCmdlet.ShouldProcess('Target proxy settings', $decision.Action)) {
            $on = $decision.Action -eq 'Enable'
            $null = Set-WinInetProxy -On $on -Server $decision.Server -Confirm:$false
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            if (([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Set-WinHttpProxy -On $on -Server $decision.Server -Confirm:$false
            } else { Write-Warning 'WinHTTP was not changed because the watcher is not elevated.' }
            if ($UpdateMT5) {
                if (Get-Process terminal64 -ErrorAction SilentlyContinue) { throw 'MT5 is running; its proxy file was not changed and MT5 was not restarted.' }
                $ini = Join-Path $config.Proxy.Mt5Directory 'Config/common.ini'
                if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { throw 'MT5 INI file not found.' }
                $encoding = [Text.Encoding]::GetEncoding(28591)
                $old = [IO.File]::ReadAllText($ini, $encoding)
                $updated = Set-IniSectionValue -Content $old -Section Common -Name ProxyEnable -Value ([string][int]$on)
                if ($on) {
                    foreach ($entry in @(@('ProxyType','2'), @('ProxyAddress',$decision.Server), @('ProxyAuth',''))) {
                        $updated = Set-IniSectionValue -Content $updated -Section Common -Name $entry[0] -Value $entry[1]
                    }
                }
                if ($updated -ne $old) {
                    Copy-Item -LiteralPath $ini -Destination ($ini + '.bak-' + [Guid]::NewGuid().ToString('N')) -ErrorAction Stop
                    [IO.File]::WriteAllText($ini, $updated, $encoding)
                }
            }
        }
        } catch {
            if (-not $Watch -or $DryRun -or $WhatIfPreference) { throw }
            Write-Warning ('Proxy sync cycle failed: ' + $_.Exception.Message)
        }
        if ($Watch -and -not ($DryRun -or $WhatIfPreference)) { Start-Sleep -Seconds $IntervalSeconds }
    } while ($Watch -and -not ($DryRun -or $WhatIfPreference))
} finally {
    if ($mutex) { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}
