[CmdletBinding()]
param([string]$ConfigPath, [string]$LocalConfigPath, [switch]$AsJson)
$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot '../Initialize-Toolkit.ps1') -ConfigPath $ConfigPath -LocalConfigPath $LocalConfigPath
$services = @(Get-CimInstance Win32_Service -ErrorAction Stop | Where-Object { $_.StartMode -eq 'Auto' } | ForEach-Object {
    $command = ConvertFrom-WindowsCommandLine $_.PathName
    $exists = $null
    if ($command.Kind -notin @('BareCommand', 'Empty', 'Invalid')) { $exists = Test-Path -LiteralPath $command.Executable -PathType Leaf }
    [pscustomobject]@{ Name=$_.Name; State=$_.State; Executable=$command.Executable; ParseKind=$command.Kind; CandidateExists=$exists }
})
$run = @(foreach ($key in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    $item = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    if (-not $item) { continue }
    foreach ($property in ($item.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
        $command = ConvertFrom-WindowsCommandLine ([string]$property.Value)
        [pscustomobject]@{ Name=$property.Name; Location=$key; Executable=$command.Executable; ParseKind=$command.Kind }
    }
})
$result = [pscustomobject]@{
    CheckedAt=(Get-Date).ToString('o'); Computer=$env:COMPUTERNAME; Services=$services; RunEntries=$run
    ExpectedTasks=@($config.Controller.ExpectedTasks | ForEach-Object { Get-ToolkitTask -Name $_ })
}
if ($AsJson) { $result | ConvertTo-Json -Depth 5 } else { $result }
