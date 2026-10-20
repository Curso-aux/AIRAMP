@echo off
title AIRA SMTP Bridge Service
color 0b
echo ===================================================
echo           AIRA SMTP Bridge Service Daemon          
echo ===================================================
echo.

:: Check if port 8088 is already listening
netstat -ano | findstr ":8088" | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [STATUS] AIRA SMTP Bridge daemon is ALREADY ACTIVE on port 8088!
    echo Web app email delivery is ready at: http://127.0.0.1:8088/send-email
    echo.
    echo Press any key to close this window, or press Ctrl+C to terminate the bridge.
    pause >nul
    exit /b 0
)

echo Starting AIRA SMTP Bridge Daemon on port 8088...
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    python -u "%~dp0smtp_bridge.py"
    goto END
)

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    py -u "%~dp0smtp_bridge.py"
    goto END
)

echo.
echo [ERROR] Python was not found in PATH!
echo Please install Python 3.8+ or add python.exe to your PATH environment variable.
echo.
pause

:END
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] SMTP Bridge stopped with error code %ERRORLEVEL%.
    pause
)
