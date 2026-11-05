$out = 'C:\Users\Vic\Desktop\mousekeys-state.txt'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MK2 {
    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEKEYS {
        public uint cbSize; public uint dwFlags; public uint iMaxSpeed;
        public uint iTimeToMaxSpeed; public uint iCtrlSpeed;
        public uint dwReserved1; public uint dwReserved2;
    }
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint a, uint p, ref MOUSEKEYS m, uint f);
}
'@
$mk = New-Object MK2+MOUSEKEYS
$mk.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf($mk)
[MK2]::SystemParametersInfo(0x0036, 0, [ref]$mk, 0) | Out-Null
"MouseKeys flags: $($mk.dwFlags) on=$((($mk.dwFlags -band 1) -ne 0))" | Out-File $out -Encoding utf8
Get-PnpDevice -Class Mouse -ErrorAction SilentlyContinue |
    Select-Object Status, FriendlyName |
    Format-Table -AutoSize | Out-File $out -Append -Encoding utf8
