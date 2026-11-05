# Enables Windows Mouse Keys for the current user. MWB synthesizes/draws its
# own cursor when the target machine has no pointing device; Mouse Keys makes
# Windows expose one, which stops the blinking drawn cursor.
$key = 'HKCU:\Control Panel\Accessibility\MouseKeys'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
Set-ItemProperty -Path $key -Name Flags -Value '63' -Type String

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MouseKeys {
    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEKEYS {
        public uint cbSize;
        public uint dwFlags;
        public uint iMaxSpeed;
        public uint iTimeToMaxSpeed;
        public uint iCtrlSpeed;
        public uint dwReserved1;
        public uint dwReserved2;
    }
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref MOUSEKEYS pvParam, uint fWinIni);
}
'@

$mk = New-Object MouseKeys+MOUSEKEYS
$mk.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf($mk)
$mk.dwFlags = 63
$mk.iMaxSpeed = 10
$mk.iTimeToMaxSpeed = 5000
$mk.iCtrlSpeed = 0
[MouseKeys]::SystemParametersInfo(0x0037, 0, [ref]$mk, 3) | Out-Null

'Mouse Keys enabled; Flags=' + (Get-ItemProperty $key).Flags
