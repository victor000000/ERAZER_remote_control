@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Control-SQX.ps1" %*
exit /b %errorlevel%
