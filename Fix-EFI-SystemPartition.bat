@echo off
setlocal
title Windows 11 Update - EFI System Partition Fix

:: Check for Administrator privileges; self-elevate if not admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "SCRIPT=%~dp0scripts\Fix-EFI-SystemPartition.ps1"
if not exist "%SCRIPT%" (
    set "SCRIPT=%~dp0Fix-EFI-SystemPartition.ps1"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
