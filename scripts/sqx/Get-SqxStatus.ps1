[CmdletBinding()]
param([string]$Project, [string]$ConfigPath, [string]$LocalConfigPath, [switch]$AsJson)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
if (-not $Project) { $Project = $config.Sqx.Project }
$content = Invoke-SqxRequest -Command (New-SqxProjectCommand status $Project) -ApiBase $config.Sqx.ApiBase
$status = ConvertFrom-SqxStatus $content
$processes = @(Get-Process sqcli -ErrorAction SilentlyContinue)
$bank = Join-Path $config.Sqx.InstallDirectory ('user/projects/' + $Project + '/databanks/databank1_S001_use_nasdaq100')
$saved = $null; $latest = $null
if (Test-Path -LiteralPath $bank -PathType Container) {
    $files = @(Get-ChildItem -LiteralPath $bank -Filter '*.sqx' -File -ErrorAction Stop)
    $saved = $files.Count
    if ($saved) { $latest = ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime }
}
$logs = Join-Path $config.Sqx.InstallDirectory ('user/projects/' + $Project + '/log')
$taskTitle = $null
if (Test-Path -LiteralPath $logs) {
    $log = Get-ChildItem -LiteralPath $logs -Filter 'global_log_*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($log) {
        $lastStart = @(Select-String -LiteralPath $log.FullName -Pattern '^Task: (.+), Type:' | Select-Object -Last 1)
        if ($lastStart.Count) { $taskTitle = $lastStart[0].Matches[0].Groups[1].Value }
    }
}
$result = [pscustomobject]@{
    CheckedAt = (Get-Date).ToString('o'); Project = $Project; EnginePresent = ($processes.Count -gt 0)
    LastLoggedTask = $taskTitle; Status = $status
    NasdaqDatabankSavedCount = $saved; LatestSave = $latest
    Processes = @($processes | Select-Object Id, PriorityClass, @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB)}}, @{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB)}})
}
if ($AsJson) { $result | ConvertTo-Json -Depth 5 } else { $result }
