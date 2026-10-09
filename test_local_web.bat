@echo off
echo ============================================================
echo  AIRA Platform - Testing Web Locally via Firebase Hosting
echo ============================================================

cd /d "%~dp0"
echo Starting Firebase Hosting Emulator...
echo The web app will be available at: http://localhost:5000
echo.
call npx firebase emulators:start --only hosting
