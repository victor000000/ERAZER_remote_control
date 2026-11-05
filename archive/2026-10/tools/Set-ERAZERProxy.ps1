# Sets the Windows (WinINET + WinHTTP) system proxy to the HypoMux proxy
# running on the PC that hosts the hotspot.
$ErrorActionPreference = 'Stop'
$server = '192.168.137.1:7897'
$bypass = '<local>;192.168.137.*;10.*;169.254.*'

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty -Path $key -Name ProxyEnable -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name ProxyServer -Value $server -Type String
Set-ItemProperty -Path $key -Name ProxyOverride -Value $bypass -Type String
Set-ItemProperty -Path $key -Name AutoConfigURL -Value '' -Type String -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinINet {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr h, int option, IntPtr buffer, int len);
}
'@
[WinINet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null  # SETTINGS_CHANGED
[WinINet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null  # REFRESH

netsh winhttp set proxy proxy-server="$server" bypass-list="$bypass" | Out-Null

Get-ItemProperty -Path $key |
    Select-Object ProxyEnable, ProxyServer, ProxyOverride |
    Format-List
netsh winhttp show proxy
