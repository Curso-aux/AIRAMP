@echo off
title AIRA SMTP Bridge Service
echo Starting AIRA SMTP Bridge Daemon on port 8088...
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    py "%~dp0smtp_bridge.py"
) else (
    python "%~dp0smtp_bridge.py"
)
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to start SMTP Bridge daemon.
    pause
)
