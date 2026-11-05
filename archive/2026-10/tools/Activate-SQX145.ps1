param(
    [string]$Install = 'C:\StrategyQuantX145',
    [string]$License = $env:SQX_LICENSE
)

$ErrorActionPreference = 'Continue'
$resultFile = 'C:\Users\Vic\Desktop\sqx145-activate-result.txt'

Get-Process StrategyQuantX_ui -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Install*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Get-Process StrategyQuantX -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Install*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

function Invoke-Sqx([string]$arguments, [int]$timeoutMs) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $Install 'sqcli.exe'
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = $Install
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $exited = $p.WaitForExit($timeoutMs)
    if (-not $exited) {
        try { $p.Kill() } catch { }
        Start-Sleep -Seconds 2
    }
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    return "exited=$exited`r`n--- STDOUT ---`r`n$stdout`r`n--- STDERR ---`r`n$stderr"
}

$out = New-Object System.Text.StringBuilder
[void]$out.AppendLine('=== LICENSE ACTIVATION ===')
[void]$out.AppendLine((Invoke-Sqx "license=$License" 300000))
[void]$out.AppendLine('=== PROJECT LIST ===')
[void]$out.AppendLine((Invoke-Sqx '-project action=list' 300000))
[IO.File]::WriteAllText($resultFile, $out.ToString(), [Text.Encoding]::UTF8)
Write-Output $out.ToString()
