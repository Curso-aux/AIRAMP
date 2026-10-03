@echo off
title AIRA SMTP Bridge Service
echo Starting AIRA SMTP Bridge Daemon...
python "%~dp0smtp_bridge.py"
pause
