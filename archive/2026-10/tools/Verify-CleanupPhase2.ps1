$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

Get-Process SecHealthUI -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep -Seconds 1

W '--- DEFENDER ---'
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    W ('RTP=' + $mp.RealTimeProtectionEnabled + ' Behavior=' + $mp.BehaviorMonitorEnabled + ' IOAV=' + $mp.OnAccessProtectionEnabled + ' Tamper=' + $mp.IsTamperProtected + ' AV=' + $mp.AntivirusEnabled)
} catch { W 'status failed' }

W '--- HONOR/QAX SERVICES REMAINING ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'HONOR|Honor|qianxin|HunterCamp' } |
    Select-Object Name, State, StartMode | Format-Table -AutoSize | Out-String | Write-Output

W '--- HONOR PROCESSES ---'
$hp = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'PCManager|HnPCAI|HNPCInfer|HunterCamp|Qax|qax|HnUpdate' }
if ($hp) { $hp | Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output } else { W 'none running' }

W '--- XBOX / STORE APPS ---'
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Xbox|GamingApp|GamingServices' } |
    Select-Object Name, Version | Format-Table -AutoSize | Out-String | Write-Output

W '--- KEPT APPS ---'
foreach ($n in @('Microsoft.Todos', 'Microsoft.Windows.Photos', 'Microsoft.WindowsCamera', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.ZuneMusic')) {
    $p = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
    W ('  ' + $n + ' present=' + [bool]$p)
}

W '--- UBI SOFT ---'
W ('UpcElevationService=' + [bool](Get-Service UpcElevationService -ErrorAction SilentlyContinue))
W ('Ubisoft tasks=' + @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -match 'Ubisoft' }).Count)
W ('Ubisoft Connect installed=' + [bool](Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Uplay' -ErrorAction SilentlyContinue))

W '--- NAHIMIC ---'
W ('NahimicService=' + (Get-Service NahimicService -ErrorAction SilentlyContinue).Status + '/' + (Get-Service NahimicService -ErrorAction SilentlyContinue).StartType)
W ('Nahimic appx=' + [bool](Get-AppxPackage -Name 'A-Volute.Nahimic' -ErrorAction SilentlyContinue))

W '--- AUDIO ---'
W ('Audiosrv=' + (Get-Service Audiosrv).Status + ' AudioEndpointBuilder=' + (Get-Service AudioEndpointBuilder).Status)

W '--- PC MANAGER REMNANT ---'
if (Test-Path 'C:\Program Files\HONOR\PCManager') {
    $s = (Get-ChildItem 'C:\Program Files\HONOR\PCManager' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    W ('folder MB=' + [math]::Round($s/1MB,1))
}
W ('uninstall entry=' + [bool](Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PC Manager' -ErrorAction SilentlyContinue))

W '--- DISK / RAM ---'
Get-PSDrive C | ForEach-Object { W ('C: free GB=' + [math]::Round($_.Free/1GB,1)) }
$os = Get-CimInstance Win32_OperatingSystem
W ('RAM free MB=' + [math]::Round($os.FreePhysicalMemory/1KB))
