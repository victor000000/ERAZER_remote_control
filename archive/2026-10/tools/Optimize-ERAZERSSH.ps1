$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$config = 'C:\ProgramData\ssh\sshd_config'
$backup = $config + '.bak-optimize-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $config $backup -Force
Write-Output ('backup: ' + $backup)

$wanted = @(
    'ClientAliveInterval 30',
    'ClientAliveCountMax 10',
    'TCPKeepAlive yes',
    'UseDNS no',
    'GSSAPIAuthentication no',
    'LoginGraceTime 30',
    'MaxStartups 30:30:100',
    'MaxSessions 20',
    'KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org',
    'Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com',
    'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com'
)
$keys = $wanted | ForEach-Object { ($_ -split '\s+')[0] }
$existing = Get-Content $config
$kept = $existing | Where-Object {
    $k = ($_ -split '\s+')[0]
    $k -notin $keys
}
$kept + $wanted | Set-Content -Path $config -Encoding ASCII
Write-Output '--- active config after edit ---'
Get-Content $config | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { Write-Output $_ }

$test = & 'C:\Windows\System32\OpenSSH\sshd.exe' -t 2>&1
Write-Output ('sshd -t: ' + (($test | Out-String).Trim()))
if ($LASTEXITCODE -eq 0) {
    Restart-Service sshd -Force -ErrorAction Continue
    Start-Sleep -Seconds 2
    Get-Service sshd | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
} else {
    Write-Output 'sshd config test failed; restoring backup'
    Copy-Item $backup $config -Force
    Restart-Service sshd -Force -ErrorAction SilentlyContinue
}

Write-Output '--- RECOVERY ---'
sc.exe qfailure sshd 2>&1 | ForEach-Object { Write-Output $_ }

Write-Output '--- WINRM SECOND CHANNEL ---'
try {
    Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
    Write-Output 'Enable-PSRemoting: ok'
} catch { Write-Output ('Enable-PSRemoting failed: ' + $_.Exception.Message) }
Get-Service WinRM -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize | Out-String | Write-Output
Test-WSMan -ComputerName localhost -ErrorAction SilentlyContinue |
    Select-Object ProductVersion, ProtocolVersion | Format-List | Out-String | Write-Output
