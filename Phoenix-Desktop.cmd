@echo off
setlocal
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo Phoenix requires PowerShell 7 or later.
    pause
    exit /b 1
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Tools\Start-PhoenixControlCenter.ps1" -Mode Desktop

if errorlevel 1 pause

endlocal
