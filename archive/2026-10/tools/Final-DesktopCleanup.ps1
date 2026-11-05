$ProgressPreference = 'SilentlyContinue'
$desk = 'C:\Users\Vic\Desktop'
$tools = 'C:\Users\Vic\ERAZER-Tools'
$misc = Join-Path $tools 'Misc'
$logs = Join-Path $tools 'Logs'
$back = Join-Path $tools 'Backups'

function Move-IfExists([string]$name, [string]$dest) {
    $src = Join-Path $desk $name
    if (Test-Path -LiteralPath $src) {
        Move-Item -LiteralPath $src -Destination (Join-Path $dest $name) -Force
        Write-Output ("moved: " + $name)
    }
}

foreach ($n in @('Check-Network.ps1', 'Confirm-SQXExit.ps1', 'List-SQXWindows.ps1')) { Move-IfExists $n $misc }
Move-IfExists 'Patch-SQXProjectPaths.ps1' $back
Get-ChildItem -LiteralPath $desk -File -Filter 'PowerPlan-backup-*.pow' -ErrorAction SilentlyContinue |
    Move-Item -Destination $back -Force
Move-IfExists 'proj_entryrev.cfx' $back
Move-IfExists 'sqx-cli-help.txt' $logs
Move-IfExists 'sqx-exit-confirm.txt' $logs
Move-IfExists 'sqx-patch-result.txt' $logs

Unregister-ScheduledTask -TaskName 'OrganizeDesktop' -Confirm:$false -ErrorAction SilentlyContinue

Write-Output '=== DESKTOP ==='
Get-ChildItem -LiteralPath $desk | Select-Object Name, Mode | Format-Table -AutoSize
