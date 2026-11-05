@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-SQX145-Project.ps1" %*
exit /b %errorlevel%
