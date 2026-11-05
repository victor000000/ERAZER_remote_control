#requires -Version 5.1
<# Runs locally on ERAZER. Repair addressing after an SSID change without touching SQX.
   Default is observation only. The deployed task uses -Apply, once a minute and at boot. #>
param([switch]$Apply, [string]$StateDirectory='C:\Users\Vic\ERAZER-Tools\Network')
$ErrorActionPreference='Stop'
function Invoke-ConnectivityNetsh([string]$Arguments) {
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=Join-Path $env:WINDIR 'System32\netsh.exe'
    $start.Arguments=$Arguments; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($start)
    $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $code=$process.ExitCode; $text=$stdout.Result; $errorText=$stderr.Result; $process.Dispose()
    if($code -ne 0){throw "netsh failed ($code): $Arguments; $text $errorText"}
    return $text
}
function Get-AddressRepairPlan([string]$Ssid,[bool]$Dhcp,[string[]]$Addresses,[string[]]$Gateways) {
    if($Ssid -eq 'HypoMux') {
        if($Dhcp -or '192.168.137.37' -notin $Addresses -or '192.168.137.1' -notin $Gateways) { return 'HypoMuxStatic' }
        return 'None'
    }
    if($Ssid -in @('MiFi-1A8F','MiFi706425-5G')) {
        if(-not $Dhcp -or @($Addresses|Where-Object {$_ -like '192.168.137.*'}).Count) {return 'MiFiDhcp'}
        return 'None'
    }
    return 'Unmanaged'
}
if($MyInvocation.InvocationName -eq '.') {return}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if($env:COMPUTERNAME -ne 'ERAZER-6JMHAKCD') {throw 'This repair runs only on ERAZER'}
New-Item -ItemType Directory -Path $StateDirectory -Force|Out-Null
$mutex=[Threading.Mutex]::new($false,'Global\ERAZERConnectivityRepair')
if(-not $mutex.WaitOne(0)) {$mutex.Dispose();return}
try {
    $wlan=Invoke-ConnectivityNetsh 'wlan show interfaces'
    $ssid=if($wlan -match '(?m)^\s*SSID\s*:\s*([^\r\n]+)') {$Matches[1].Trim()} else {''}
    $i=Get-NetIPInterface -InterfaceAlias WLAN -AddressFamily IPv4
    $addresses=@(Get-NetIPAddress -InterfaceAlias WLAN -AddressFamily IPv4 -ErrorAction SilentlyContinue|Select-Object -ExpandProperty IPAddress)
    $gateways=@(Get-NetRoute -InterfaceAlias WLAN -AddressFamily IPv4 -ErrorAction SilentlyContinue|Where-Object DestinationPrefix -eq '0.0.0.0/0'|Select-Object -ExpandProperty NextHop)
    $plan=Get-AddressRepairPlan $ssid ($i.Dhcp -eq 'Enabled') $addresses $gateways
    $actions=@()
    if($Apply) {
        if($plan -eq 'HypoMuxStatic') {
            Invoke-ConnectivityNetsh 'interface ipv4 set address name=WLAN static 192.168.137.37 255.255.255.0 192.168.137.1' | Out-Null
            Invoke-ConnectivityNetsh 'interface ipv4 set dnsservers name=WLAN static 192.168.137.1 primary' | Out-Null
            $actions+='Restored HypoMux static address and DNS'
        } elseif($plan -eq 'MiFiDhcp') {
            Invoke-ConnectivityNetsh 'interface ipv4 set address name=WLAN source=dhcp' | Out-Null
            Invoke-ConnectivityNetsh 'interface ipv4 set dnsservers name=WLAN source=dhcp' | Out-Null
            $actions+='Enabled MiFi DHCP address and DNS'
        } elseif(-not $ssid) {
            # Connect only to known, saved profiles when disconnected. No radio reset.
            $visible=Invoke-ConnectivityNetsh 'wlan show networks'
            foreach($name in @('HypoMux','MiFi-1A8F','MiFi706425-5G')) {
                if($visible -match ('(?m)^\s*SSID\s+\d+\s*:\s*'+[regex]::Escape($name)+'\s*$')) {
                    Invoke-ConnectivityNetsh "wlan connect name=$name interface=WLAN"|Out-Null
                    $actions+='Requested saved profile '+$name
                    break
                }
            }
        }
        $ssh=Get-Service sshd
        if($ssh.StartType -ne 'Automatic'){Set-Service sshd -StartupType Automatic;$actions+='SSH automatic startup restored'}
        if($ssh.Status -ne 'Running'){Start-Service sshd;$actions+='SSH started'}
    }
    $result=[pscustomobject]@{At=(Get-Date).ToString('o');SSID=$ssid;DhcpBefore=$i.Dhcp.ToString();AddressesBefore=$addresses;GatewaysBefore=$gateways;Plan=$plan;Apply=[bool]$Apply;Actions=$actions;SSH=(Get-Service sshd).Status.ToString();Account=$identity.Name}
    $json=$result|ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText((Join-Path $StateDirectory 'connectivity-latest.json'),$json)
    if($actions.Count){Add-Content (Join-Path $StateDirectory 'connectivity-actions.jsonl') ($result|ConvertTo-Json -Compress -Depth 4)}
    $json
} catch {
    Add-Content (Join-Path $StateDirectory 'connectivity-errors.log') ((Get-Date).ToString('o')+' '+$_.Exception.Message)
    throw
} finally {$mutex.ReleaseMutex();$mutex.Dispose()}
