@echo off
rem Runs the Tailscale UDP 41641 firewall helper and tees its output to out\.
rem Relative paths keep this working if the repo moves. Elevation comes from the
rem caller (Start-TailscaleFirewallTask.ps1 registers it with RunLevel Highest).
if not exist "%~dp0..\out" mkdir "%~dp0..\out"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Add-TailscaleFirewall-All.ps1" > "%~dp0..\out\ts-fw.txt" 2>&1
