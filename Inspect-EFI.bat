@echo off
setlocal
title EFI System Partition Inspector

:: Check for Administrator privileges; self-elevate if not admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "SCRIPT=%~dp0scripts\Inspect-EFI.ps1"
if not exist "%SCRIPT%" (
    set "SCRIPT=%~dp0Inspect-EFI.ps1"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
