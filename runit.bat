@echo off

if "%~1"=="" (
    echo Usage:
    echo    download-logos.bat playlist.m3u
    echo.
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%~dp0download-logos.ps1" "%~1"

pause