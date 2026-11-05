$ProgressPreference = 'SilentlyContinue'

# Resolve the real Unicode profile name from the WLAN profile XML.
$base = 'C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces'
$pname = $null
$profileFile = $null
foreach ($dir in (Get-ChildItem $base -Directory -ErrorAction SilentlyContinue)) {
    foreach ($f in (Get-ChildItem $dir.FullName -Filter '*.xml' -ErrorAction SilentlyContinue)) {
        try {
            $xmlText = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
            [xml]$x = $xmlText
            $n = $x.WLANProfile.name
            if ($n -and $n -match 'WIN Turbo') {
                $pname = $n
                $profileFile = $f.FullName
                break
            }
        } catch { }
    }
    if ($pname) { break }
}

if (-not $pname) {
    Write-Output 'profile name not found in WLAN profile XML'
    exit 1
}

Write-Output ("profile=" + $pname)
Write-Output ("profileFile=" + $profileFile)
$codepoints = (($pname.ToCharArray() | ForEach-Object { [int]$_ }) -join ',')
Write-Output ("codepoints=" + $codepoints)

$cmd = "@echo off`r`nchcp 936 >nul`r`nnetsh wlan set profileparameter name=`"$pname`" connectionmode=manual`r`n"
$tmp = Join-Path $env:TEMP 'set-profile-936.cmd'
[IO.File]::WriteAllText($tmp, $cmd, [Text.Encoding]::GetEncoding(936))
$result = & cmd.exe /c $tmp 2>&1
$result | ForEach-Object { Write-Output $_ }

# Verify from the XML.
try {
    $xmlText = [IO.File]::ReadAllText($profileFile, [Text.Encoding]::UTF8)
    [xml]$x = $xmlText
    Write-Output ("connectionMode=" + $x.WLANProfile.connectionMode)
} catch {
    Write-Output ('verify failed: ' + $_.Exception.Message)
}
