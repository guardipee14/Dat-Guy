@echo off
setlocal

title Phoenix Installer
cd /d "%~dp0"

set "PHOENIX_PWSH=pwsh.exe"
set "PHOENIX_INSTALLER=%~dp0Install-Phoenix.ps1"

where pwsh.exe >nul 2>&1

if errorlevel 1 (
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        set "PHOENIX_PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    ) else (
        echo.
        echo Phoenix requires PowerShell 7.4 or later.
        echo Install PowerShell 7 and then run this installer again.
        echo.
        echo https://aka.ms/powershell
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Phoenix Installer
echo =================
echo.
echo Installing Phoenix for the current Windows user...
echo.

"%PHOENIX_PWSH%" ^
    -NoLogo ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -Command ^
    "$ErrorActionPreference = 'Stop'; if ($PSVersionTable.PSVersion -lt [version]'7.4.0') { throw 'Phoenix requires PowerShell 7.4 or later.' }; & $env:PHOENIX_INSTALLER -ErrorAction Stop"

set "PHOENIX_EXIT_CODE=%ERRORLEVEL%"

echo.

if "%PHOENIX_EXIT_CODE%"=="0" (
    echo Phoenix installation completed successfully.
) else (
    echo Phoenix installation failed with exit code %PHOENIX_EXIT_CODE%.
)

echo.
pause
exit /b %PHOENIX_EXIT_CODE%
