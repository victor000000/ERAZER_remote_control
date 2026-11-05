$ErrorActionPreference = 'Stop'
$script = 'C:\Users\victo\ERAZER_remote_control\tools\Apply-LocalCleanup2.ps1'
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $script
    )
    if ($p.WaitForExit(540000)) {
        Write-Output ('elevated exit code=' + $p.ExitCode)
    } else {
        Write-Output 'elevated process still running after 9 minutes'
    }
} catch {
    Write-Output ('elevation failed: ' + $_.Exception.Message)
}
