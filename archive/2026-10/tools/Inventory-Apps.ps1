# Inventory for the ERAZER cleanup: installed apps, non-Microsoft Store
# packages, printers, Bluetooth devices, power schemes, and candidate
# services. Output is base64(UTF-16 JSON) so Chinese names survive SSH.
$paths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$apps = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, Publisher, DisplayVersion, InstallLocation, UninstallString, QuietUninstallString

$appx = Get-AppxPackage -ErrorAction SilentlyContinue |
    Where-Object { $_.Publisher -notmatch 'Microsoft' } |
    Select-Object Name, PackageFullName

$printers = Get-Printer -ErrorAction SilentlyContinue |
    Select-Object Name, DriverName, PortName

$bt = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
    Select-Object FriendlyName, Status, InstanceId

$candidates = 'SysMain', 'WSearch', 'Spooler', 'Fax', 'XblAuthManager', 'XblGameSave',
    'XboxNetApiSvc', 'XboxGipSvc', 'DiagTrack', 'WerSvc', 'MapsBroker', 'PhoneSvc',
    'WMPNetworkSvc', 'RemoteRegistry', 'RetailDemo', 'WalletService', 'bthserv',
    'BTAGService', 'BthAvctpSvc', 'BthHFSrv', 'TabletInputService'
$services = Get-Service -Name $candidates -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, Status, StartType

$power = powercfg /list

$data = [pscustomobject]@{
    Apps      = $apps
    Appx      = $appx
    Printers  = $printers
    Bluetooth = $bt
    Services  = $services
    Power     = $power
}

$out = 'C:\Windows\Temp\erazer-inventory.json'
($data | ConvertTo-Json -Depth 6) | Out-File -FilePath $out -Encoding UTF8
"written: $out"
