$ErrorActionPreference = 'Stop'
$script = 'C:\Users\victo\ERAZER_remote_control\tools\Apply-LocalCleanup.ps1'
$log = 'C:\Users\victo\ERAZER_remote_control\local-cleanup-log.txt'
if (Test-Path $log) { Remove-Item $log -Force }
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $script
    )
    Write-Output ('elevated exit code=' + $p.ExitCode)
} catch {
    Write-Output ('elevation failed: ' + $_.Exception.Message)
}
if (Test-Path $log) { Write-Output '--- LOG ---'; Get-Content $log }
