$ProgressPreference = 'SilentlyContinue'
$out = 'C:\Users\Vic\Desktop\network-fix.txt'
$lines = New-Object System.Collections.Generic.List[string]

function L([string]$m) {
    $lines.Add($m)
    Write-Output $m
}

L '=== MWB SERVICE ==='
Set-Service MouseWithoutBordersSvc -StartupType Automatic -ErrorAction SilentlyContinue
try {
    Start-Service MouseWithoutBordersSvc -ErrorAction Stop
    L 'MWB service started'
} catch {
    L ('MWB service start: ' + $_.Exception.Message)
}
Get-Service MouseWithoutBordersSvc |
    Select-Object Name, Status, StartType |
    Format-Table -AutoSize |
    Out-String |
    ForEach-Object { $_.Trim() -split "`r?`n" } |
    ForEach-Object { if ($_) { L $_ } }

L '=== PHONE HOTSPOT PROFILE ==='
$line = (netsh wlan show profiles) | Select-String -Pattern 'WIN Turbo' | Select-Object -First 1
if ($line) {
    $text = $line.Line
    $idx = $text.IndexOf(':')
    if ($idx -ge 0) {
        $pname = $text.Substring($idx + 1).Trim()
        L ("profile=" + $pname)
        $result = netsh wlan set profileparameter name="$pname" connectionmode=manual 2>&1
        $result | Out-String | ForEach-Object { $_.Trim() -split "`r?`n" } | ForEach-Object { if ($_) { L $_ } }
    }
} else {
    L 'phone profile not found'
}

L '=== WLAN STATE ==='
(netsh wlan show interfaces) | ForEach-Object { L $_ }

$lines | Set-Content -LiteralPath $out -Encoding UTF8
