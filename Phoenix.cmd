@echo off
setlocal
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo Phoenix requires PowerShell 7 or later.
    echo Install PowerShell 7 and try again.
    pause
    exit /b 1
)

echo.
echo Phoenix Control Center
echo ======================
echo [D] Desktop window
echo [C] Interactive console
echo [A] Automatic selection
echo [Q] Quit
echo.

choice /C DCAQ /N /M "Choose a launch mode: "

if errorlevel 4 exit /b 0
if errorlevel 3 set "PHOENIX_MODE=Auto"
if errorlevel 2 set "PHOENIX_MODE=Console"
if errorlevel 1 set "PHOENIX_MODE=Desktop"

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Tools\Start-PhoenixControlCenter.ps1" -Mode "%PHOENIX_MODE%"

if errorlevel 1 (
    echo.
    echo Phoenix Control Center closed with an error.
    pause
)

endlocal
