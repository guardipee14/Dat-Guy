@echo off
setlocal
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo Phoenix Theme Studio requires PowerShell 7 or later.
    pause
    exit /b 1
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Tools\Open-PhoenixThemeStudio.ps1"

if errorlevel 1 pause

endlocal
