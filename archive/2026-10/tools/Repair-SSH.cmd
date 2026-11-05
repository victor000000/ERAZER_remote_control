@echo off
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
sc query sshd >nul 2>&1
if errorlevel 1 (
    sc create sshd binPath= "C:\Windows\System32\OpenSSH\sshd.exe" start= auto DisplayName= "OpenSSH SSH Server"
    sc description sshd "OpenSSH SSH Server"
)
sc config sshd start= auto
netsh advfirewall firewall show rule name=sshd >nul 2>&1 || netsh advfirewall firewall add rule name=sshd dir=in action=allow protocol=TCP localport=22
sc start sshd
sc query sshd
pause
