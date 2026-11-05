Set sh = CreateObject("WScript.Shell")
sh.Run """C:\Program Files\PowerShell\7\pwsh.exe"" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Users\Vic\Desktop\Sync-ProxyWithNetwork.ps1"" -Watch -SkipMT5", 0, False
