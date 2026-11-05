[CmdletBinding(SupportsShouldProcess)]
param([string]$Address, [switch]$UseSavedPassword, [switch]$Reconnect, [string]$CredentialPath, [string]$ConfigPath, [string]$LocalConfigPath)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Address) { $Address = $config.Target.LanAddress }
$ip = $null
if (-not [Net.IPAddress]::TryParse($Address, [ref]$ip)) { throw 'Address must be a literal target IP address.' }
$exe = Join-Path $env:ProgramFiles 'RustDesk/rustdesk.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'RustDesk is not installed at the expected path.' }
$password = $null
try {
    if ($UseSavedPassword) {
        if (-not $CredentialPath) { $CredentialPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'credentials.local.txt' }
        $entries = Get-Content -LiteralPath $CredentialPath -ErrorAction Stop
        $entry = $entries | Where-Object { $_ -match '(?i)rustdesk' -and $_ -match '(?i)[?&]password=' } | Select-Object -First 1
        $match = [regex]::Match([string]$entry, '(?i)[?&]password=([^&\s]+)')
        if (-not $match.Success) { throw 'Saved RustDesk deep-link password not found.' }
        $password = [Uri]::UnescapeDataString($match.Groups[1].Value).Trim([char[]]@(34,39,96))
        if (-not $password) { throw 'Saved RustDesk password is empty.' }
    }
    if ($PSCmdlet.ShouldProcess($Address, 'Open RustDesk connection (a window alone does not prove authentication)')) {
        if ($Reconnect) {
            foreach ($process in @(Get-Process rustdesk -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle.StartsWith($Address + '@', [StringComparison]::Ordinal) })) {
                if (-not $process.CloseMainWindow()) { throw 'Existing connection window did not close; no service was stopped.' }
                if (-not $process.WaitForExit(10000)) { throw 'Existing session is still open; refusing to start another credentialed session.' }
            }
        }
        $tokens = @('--connect', $Address)
        if ($password) { $tokens += @('--password', $password) }
        $arguments = ($tokens | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
        # RustDesk accepts a launch-time password only for a newly opened peer session.
        Start-Process -FilePath $exe -ArgumentList $arguments -ErrorAction Stop
        Write-Output "RustDesk connection requested for $Address. Verify the remote desktop, not just its window title."
    }
} finally { $password=$null; $entry=$null; $entries=$null; $arguments=$null; $tokens=$null }
