<#
  Connects to the ERAZER over SSH and finds its current IP automatically.
  The hotspot's DHCP may assign a different address after a reboot, so if
  the last known address does not answer, this scans the local /24 subnets
  for an SSH server and verifies it by hostname.

  Usage:
    .\Connect-ERAZER.ps1                       # interactive shell on the ERAZER
    .\Connect-ERAZER.ps1 hostname              # run one command
    .\Connect-ERAZER.ps1 -ForceScan hostname   # skip the last known address
    .\Connect-ERAZER.ps1 -UpdateTargetRecord hostname # explicitly refresh SSH/hosts
#>
param(
    [switch]$ForceScan,
    [switch]$UpdateTargetRecord,
    [switch]$ResolveOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command
)

$ErrorActionPreference = 'Stop'

$user        = 'Vic'
$key         = Join-Path $env:USERPROFILE '.ssh\erazer_ed25519'
$knownHosts  = Join-Path $env:USERPROFILE '.ssh\erazer_known_hosts'
$expectedHost = 'ERAZER-6JMHAKCD'
$lastKnown   = '192.168.137.37'

$ssh = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
if (-not (Test-Path $ssh)) { $ssh = 'ssh' }

function Invoke-Remote([string]$ip, [string[]]$remoteCommand) {
    $sshArgs = @(
        '-i', $key,
        '-o', 'BatchMode=yes',
        '-o', 'ConnectTimeout=5',
        '-o', 'StrictHostKeyChecking=yes',
        '-o', 'HostKeyAlias=100.105.143.1',
        '-o', "UserKnownHostsFile=$knownHosts",
        "$user@$ip"
    ) + $remoteCommand
    # Use explicit process I/O: native invocation can be silent under WSL PowerShell.
    $quoted=foreach($arg in $sshArgs){
        if($arg -notmatch '[\s"]'){$arg}
        else{'"'+([regex]::Replace([regex]::Replace($arg,'(\\*)"','$1$1\"'),'(\\+)$','$1$1'))+'"'}
    }
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$ssh; $start.Arguments=$quoted -join ' '
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($start)
    $output=$process.StandardOutput.ReadToEndAsync()
    $errors=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    if($output.Result){Write-Output $output.Result.TrimEnd()}
    if($errors.Result){[Console]::Error.Write($errors.Result)}
    $code=$process.ExitCode; $process.Dispose()
    if($code -ne 0){throw "ERAZER SSH command exited with code $code; inspect remote state before retrying"}
}

function Test-ERAZER([string]$ip) {
    try {
        # Explicit redirection also works when PowerShell was launched by WSL.
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=$ssh
        $start.Arguments="-o BatchMode=yes -o ConnectTimeout=5 -o HostName=$ip -o HostKeyAlias=100.105.143.1 -o StrictHostKeyChecking=yes erazer-ts hostname"
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
        $process=[Diagnostics.Process]::Start($start)
        $output=$process.StandardOutput.ReadToEndAsync()
        $errors=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(12000)){$process.Kill();$process.Dispose();return $false}
        $valid=$process.ExitCode -eq 0 -and $output.Result.Trim() -eq $expectedHost
        $process.Dispose()
        return $valid
    }
    catch { return $false }
}

function Get-MiFiTarget {
    # DHCP leases change. Read only the known router's target record, then pin SSH.
    try {
        function Read-MiFi([string]$name) {
            $stamp=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $request=[Net.HttpWebRequest]::Create("http://192.168.1.1/xml_action.cgi?method=get&module=duster&file=json_${name}${stamp}")
            $request.Proxy=$null; $request.Timeout=3500
            $response=$request.GetResponse()
            $reader=[IO.StreamReader]::new($response.GetResponseStream())
            try { return ($reader.ReadToEnd() | ConvertFrom-Json) }
            finally { $reader.Dispose(); $response.Dispose() }
        }
        $status=Read-MiFi 'homepage_info'
        $bytes=for($i=0;$i -lt $status.ssid.Length;$i+=2){[Convert]::ToByte($status.ssid.Substring($i,2),16)}
        if([Text.Encoding]::BigEndianUnicode.GetString([byte[]]$bytes) -ne 'MiFi-1A8F'){return}
        $table=Read-MiFi 'device_management_info'
        foreach($row in $table.client_list) {
            if($row.m -ieq '54:ae:bc:bf:6c:37' -and $row.ip -match '^192\.168\.1\.\d{1,3}$') {
                $address=$null
                if([ipaddress]::TryParse($row.ip,[ref]$address)){ $row.ip }
            }
        }
    } catch { Write-Verbose 'MiFi device table unavailable; trying pinned local discovery.' }
}

function Repair-ConflictingControllerLease([string]$candidate) {
    $local=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -eq $candidate)
    if(-not $local.Count){return $true}
    # Only repair a stale DHCP lease on the controller's disconnected Wi-Fi.
    # Never change an active connection or a manually configured address.
    $adapter=Get-NetAdapter -ErrorAction SilentlyContinue|Where-Object ifIndex -eq $local[0].InterfaceIndex
    if($local.Count -ne 1 -or $local[0].PrefixOrigin -ne 'Dhcp' -or
       $adapter.Name -ne 'WLAN' -or $adapter.Status -ne 'Disconnected'){
        Write-Verbose "Candidate $candidate conflicts with a controller address; active/manual addressing left untouched."
        return $false
    }
    function Run-LocalNetworkCommand([string]$file,[string]$arguments) {
        $start=[Diagnostics.ProcessStartInfo]::new($file,$arguments)
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
        $process=[Diagnostics.Process]::Start($start)
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $process.WaitForExit();$code=$process.ExitCode;$process.Dispose()
        if($code -ne 0){throw "Controller lease repair failed with code $code"}
        return $stdout.Result
    }
    $netsh=Join-Path $env:WINDIR 'System32\netsh.exe'
    try {
        # Existing encrypted, manual profile only; no password reads or new profiles.
        Run-LocalNetworkCommand $netsh 'wlan show profile name=MiFi-1A8F'|Out-Null
        Run-LocalNetworkCommand $netsh 'wlan connect name=MiFi-1A8F interface=WLAN'|Out-Null
        $deadline=(Get-Date).AddSeconds(20)
        while((Get-NetAdapter -Name WLAN).Status -ne 'Up' -and (Get-Date) -lt $deadline){Start-Sleep 1}
        if((Get-NetAdapter -Name WLAN).Status -ne 'Up'){throw 'Controller Wi-Fi did not join the saved fallback'}
        $status=Run-LocalNetworkCommand $netsh 'wlan show interfaces'
        if($status -notmatch '(?m)^\s*SSID\s*:\s*MiFi-1A8F\s*$'){throw 'Controller joined a different network; do not release its lease'}
        Run-LocalNetworkCommand (Join-Path $env:WINDIR 'System32\ipconfig.exe') '/release WLAN'|Out-Null
    } catch { Write-Verbose $_.Exception.Message }
    finally { Run-LocalNetworkCommand $netsh 'wlan disconnect interface=WLAN'|Out-Null }
    $remains=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue|Where-Object IPAddress -eq $candidate)
    return $remains.Count -eq 0
}

function Get-CandidateIPs {
    $ips = @()
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|VMware|Speedify' -and
            $_.PrefixLength -eq 24
        } |
        ForEach-Object {
            $o = $_.IPAddress.Split('.')
            $base = "$($o[0]).$($o[1]).$($o[2])"
            1..254 | ForEach-Object { $ips += "$base.$_" }
        }
    $ips | Select-Object -Unique
}

function Scan-Port22([string[]]$ips) {
    Add-Type -TypeDefinition @'
using System;
using System.Linq;
using System.Net.Sockets;
using System.Threading.Tasks;
using System.Threading;
public class PortScan22 {
    static async Task<string> ScanOne(string ip, int port, int timeoutMs) {
        try {
            using (var c = new TcpClient()) {
                var connect = c.ConnectAsync(ip, port);
                var done = await Task.WhenAny(connect, Task.Delay(timeoutMs)).ConfigureAwait(false);
                if (done == connect && c.Connected) return ip;
            }
        } catch { }
        return null;
    }
    public static string[] Scan(string[] ips, int port, int timeoutMs) {
        var gate = new SemaphoreSlim(64);
        var tasks = ips.Select(async ip => {
            await gate.WaitAsync().ConfigureAwait(false);
            try { return await ScanOne(ip, port, timeoutMs).ConfigureAwait(false); }
            finally { gate.Release(); }
        }).ToArray();
        Task.WaitAll(tasks);
        return tasks.Where(t => t.Result != null).Select(t => t.Result).ToArray();
    }
}
'@ -ErrorAction SilentlyContinue
    [PortScan22]::Scan($ips, 22, 1800)
}

$target = $null

if (-not $ForceScan -and (Test-ERAZER $lastKnown)) {
    $target = $lastKnown
}

if (-not $target) {
    foreach($ip in @(Get-MiFiTarget)) {
        if((Repair-ConflictingControllerLease $ip) -and (Test-ERAZER $ip)){$target=$ip;break}
    }
}

if (-not $target) {
    if(-not $ResolveOnly){Write-Host 'Locating the ERAZER on the local network...'}
    $open = Scan-Port22 (Get-CandidateIPs)
    foreach ($ip in $open) {
        if (Test-ERAZER $ip) { $target = $ip; break }
    }
}

if (-not $target) {
    Write-Error 'Could not find the ERAZER (no SSH server found on the local subnets).'
    exit 1
}

if($ResolveOnly){Write-Output $target;exit 0}
Write-Host "ERAZER found at $target"

function Update-TargetRecord([string]$ip) {
    $cfg = Join-Path $env:USERPROFILE '.ssh\config'
    if (Test-Path -LiteralPath $cfg) {
        try {
            $lines = @(Get-Content -LiteralPath $cfg)
            $inErazer = $false
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^\s*Host\s+') {
                    $inErazer = ($lines[$i] -match '(\s|^)erazer(\s|$)')
                }
                elseif ($inErazer -and $lines[$i] -match '^(\s*HostName\s+)\S+') {
                    $lines[$i] = $matches[1] + $ip
                    break
                }
            }
            Set-Content -LiteralPath $cfg -Value $lines -Encoding ASCII
        }
        catch { }
    }

    try {
        $hosts = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
        $raw = Get-Content -LiteralPath $hosts -Raw
        if ($raw -match [regex]::Escape($expectedHost)) {
            $raw = [regex]::Replace($raw, '(?m)^\s*\S+\s+' + [regex]::Escape($expectedHost) + '\s*$', "$ip $expectedHost")
        }
        else {
            $raw = $raw.TrimEnd() + "`r`n$ip $expectedHost`r`n"
        }
        [IO.File]::WriteAllText($hosts, $raw, (New-Object System.Text.ASCIIEncoding))
    }
    catch { }
}

if ($UpdateTargetRecord) { Update-TargetRecord $target }

if ($Command) {
    Invoke-Remote $target $Command
}
else {
    & $ssh -i $key -o StrictHostKeyChecking=yes -o HostKeyAlias=100.105.143.1 -o "UserKnownHostsFile=$knownHosts" "$user@$target"
}
