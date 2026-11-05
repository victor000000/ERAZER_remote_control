@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-TradingApps.ps1" %*
exit /b %errorlevel%
