# Optimizes OBS for the UGREEN 25854 capture: 1080p60 source and a 60 fps
# canvas. Backs up both files, and requires OBS to be closed.
$ErrorActionPreference = 'Stop'

$base    = 'C:\Users\victo\AppData\Roaming\obs-studio\basic'
$sceneDir = Join-Path $base 'scenes'
$profDir  = Join-Path $base 'profiles'

if (Get-Process obs64 -ErrorAction SilentlyContinue) {
    Write-Output 'OBS is running; close it before editing.'
    exit 1
}

$scene = Get-ChildItem -LiteralPath $sceneDir -Filter *.json -ErrorAction Stop |
    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match 'UGREEN' } |
    Select-Object -First 1
$profile = Get-ChildItem -LiteralPath $profDir -Recurse -Filter basic.ini -ErrorAction Stop |
    Select-Object -First 1

if (-not $scene -or -not $profile) {
    Write-Output 'Could not locate the OBS scene or profile file.'
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $scene.FullName "$($scene.FullName).$stamp.bak" -Force
Copy-Item -LiteralPath $profile.FullName "$($profile.FullName).$stamp.bak" -Force

$t = Get-Content -LiteralPath $scene.FullName -Raw -Encoding UTF8
$t = $t.Replace('"frame_interval": 333333', '"frame_interval": 166666')
[IO.File]::WriteAllText($scene.FullName, $t, (New-Object Text.UTF8Encoding($false)))

$b = Get-Content -LiteralPath $profile.FullName -Raw
$b = $b.Replace('FPSCommon=30', 'FPSCommon=60')
[IO.File]::WriteAllText($profile.FullName, $b, (New-Object Text.UTF8Encoding($false)))

Write-Output "backups: $stamp"
Write-Output ('scene: ' + $scene.Name)
Write-Output ('profile: ' + $profile.FullName)
Select-String -LiteralPath $scene.FullName -Pattern '"frame_interval": \d+' |
    ForEach-Object { '  ' + $_.Line.Trim() }
Select-String -LiteralPath $profile.FullName -Pattern 'FPSCommon=' |
    ForEach-Object { '  ' + $_.Line.Trim() }
