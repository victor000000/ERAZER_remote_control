# Ejects the T7 USB device using the same PnP request as Safely Remove
# Hardware (CM_Request_Device_Eject). Run elevated.
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class PnpEject {
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Locate_DevNodeW(out uint devInst, string devID, int flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Request_Device_EjectW(uint devInst, out int vetoType,
        StringBuilder vetoName, int nameLen, int flags);

    public static string Eject(string instanceId) {
        uint dev;
        int cr = CM_Locate_DevNodeW(out dev, instanceId, 0);
        if (cr != 0) return "locate failed: " + cr;
        int veto;
        var sb = new StringBuilder(260);
        cr = CM_Request_Device_EjectW(dev, out veto, sb, 260, 0);
        if (cr == 0) return "ejected";
        return "eject failed: " + cr + " vetoType=" + veto + " veto=" + sb;
    }
}
'@

$dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'USB\VID_04E8&PID_61FB*' } |
    Select-Object -First 1

if (-not $dev) {
    $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'T7' -and $_.InstanceId -like 'USB*' } |
        Select-Object -First 1
}

if (-not $dev) {
    Write-Output 'T7 USB device not found'
    exit 2
}

Write-Output "instance: $($dev.InstanceId)"
Write-Output ([PnpEject]::Eject($dev.InstanceId))

Start-Sleep -Seconds 3
$disk = Get-Disk -ErrorAction SilentlyContinue | Where-Object FriendlyName -match 'T7'
Write-Output ("T7 disk present: " + [bool]$disk)
Write-Output ("E: mounted: " + (Test-Path 'E:\'))
