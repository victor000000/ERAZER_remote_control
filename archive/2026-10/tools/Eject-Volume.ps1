# Safely ejects a USB volume using the storage IOCTLs, with a shell-verb
# fallback. Run elevated (needs handle access to the volume).
param([string]$Letter = 'E')

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class EjectVolume {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFileW(string name, uint access, uint share,
        IntPtr security, uint create, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(IntPtr h, uint code, IntPtr inBuf,
        uint inSize, IntPtr outBuf, uint outSize, out uint ret, IntPtr overlapped);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr h);

    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 1;
    const uint FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const uint FSCTL_LOCK_VOLUME = 0x00090018;
    const uint FSCTL_DISMOUNT_VOLUME = 0x00090020;
    const uint IOCTL_STORAGE_EJECT_MEDIA = 0x002D4808;

    public static string Eject(string letter) {
        string path = @"\\.\" + letter + ":";
        IntPtr h = CreateFileW(path, GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (h == (IntPtr)(-1))
            return "open failed: " + Marshal.GetLastWin32Error();

        uint br;
        bool locked = DeviceIoControl(h, FSCTL_LOCK_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out br, IntPtr.Zero);
        int lockErr = Marshal.GetLastWin32Error();
        bool dismounted = DeviceIoControl(h, FSCTL_DISMOUNT_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out br, IntPtr.Zero);
        int dismountErr = Marshal.GetLastWin32Error();
        bool ejected = DeviceIoControl(h, IOCTL_STORAGE_EJECT_MEDIA, IntPtr.Zero, 0, IntPtr.Zero, 0, out br, IntPtr.Zero);
        int ejectErr = Marshal.GetLastWin32Error();
        CloseHandle(h);

        return string.Format("lock={0}({1}) dismount={2}({3}) eject={4}({5})",
            locked, lockErr, dismounted, dismountErr, ejected, ejectErr);
    }
}
'@

$result = [EjectVolume]::Eject($Letter)
Write-Output "ioctl: $result"

Start-Sleep -Seconds 2
if (Test-Path "${Letter}:\") {
    Write-Output 'volume still mounted; trying shell verb'
    try {
        $shell = New-Object -ComObject Shell.Application
        $drive = $shell.Namespace(17).ParseName("${Letter}:")
        if ($drive) {
            $ejectPattern = 'Eject|' + [char]0x5F39 + [char]0x51FA + '|' + [char]0x9000 + [char]0x51FA
            $verb = $drive.Verbs() | Where-Object { $_.Name -match $ejectPattern } | Select-Object -First 1
            if ($verb) { $verb.DoIt(); Write-Output "shell verb invoked: $($verb.Name)" }
            else { Write-Output 'no eject verb found' }
        }
        else { Write-Output 'drive not visible in shell namespace' }
    }
    catch { Write-Output "shell fallback failed: $($_.Exception.Message)" }
    Start-Sleep -Seconds 3
}

Write-Output ("E: mounted after eject: " + (Test-Path "${Letter}:\"))
Get-Volume -DriveLetter $Letter -ErrorAction SilentlyContinue |
    Select-Object DriveLetter, FileSystemLabel, Size, SizeRemaining |
    Format-Table -AutoSize | Out-String | Write-Output
