$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$config = 'C:\ProgramData\ssh\sshd_config'
Copy-Item $config ($config + '.bak-prep-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force

$directives = @(
    'ClientAliveInterval 30',
    'ClientAliveCountMax 10',
    'TCPKeepAlive yes',
    'UseDNS no',
    'GSSAPIAuthentication no',
    'LoginGraceTime 30',
    'MaxStartups 30:30:100',
    'MaxSessions 20',
    'Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com',
    'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com'
)
$keys = $directives | ForEach-Object { ($_ -split '\s+')[0] }
$lines = Get-Content $config
$lines = $lines | Where-Object { ($_ -split '\s+')[0] -notin $keys }

$matchLine = ($lines | Select-String '^\s*Match\s' | Select-Object -First 1).LineNumber
if ($matchLine) {
    $before = @($lines[0..($matchLine - 2)])
    $after = @($lines[($matchLine - 1)..($lines.Count - 1)])
    $new = $before + $directives + $after
} else {
    $new = $lines + $directives
}
$new | Set-Content -Path $config -Encoding ASCII

Write-Output '--- active config ---'
Get-Content $config | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { Write-Output $_ }

$test = & 'C:\Windows\System32\OpenSSH\sshd.exe' -t 2>&1
Write-Output ('sshd -t exit=' + $LASTEXITCODE + ': ' + (($test | Out-String).Trim()))
if ($LASTEXITCODE -eq 0) {
    Restart-Service sshd -Force -ErrorAction Continue
    Start-Sleep -Seconds 2
    Get-Service sshd | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
} else {
    Write-Output 'config test failed; restoring backup'
    Copy-Item ($config + '.bak-prep-*' | Get-ChildItem | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName $config -Force
    Restart-Service sshd -Force -ErrorAction SilentlyContinue
}

Write-Output '--- WINRM FIREWALL ---'
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize | Out-String | Write-Output
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue |
    Enable-NetFirewallRule -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize | Out-String | Write-Output
Get-Service WinRM -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Write-Output
Test-WSMan -ComputerName localhost -ErrorAction SilentlyContinue |
    Select-Object ProductVersion, ProtocolVersion | Format-List | Out-String | Write-Output
