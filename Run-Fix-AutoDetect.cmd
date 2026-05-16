@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\Fix-CodexReconnect5.ps1" -AutoDetectPort
pause
