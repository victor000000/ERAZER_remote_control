' Compatibility launcher; requires the complete repository or maintained bundle.
Option Explicit
Dim sh, fso, scriptPath, powerShellPath
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Sync-ProxyWithNetwork.ps1")
powerShellPath = sh.ExpandEnvironmentStrings("%ProgramFiles%\PowerShell\7\pwsh.exe")
sh.Run """" & powerShellPath & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """ -Watch -SkipMT5", 0, False
