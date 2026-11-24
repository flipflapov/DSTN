@echo off
rem DSTN (DASTAN): start menu for Windows. Double-click this file. The menu is scripts\dstn_start.ps1; every run
rem writes its output to logs\dstn-<date>.log, the file to send when something fails.
rem One step without the menu:  Start-DSTN.bat check   (check build testgame frame tests find game-check port)
rem This file stays ASCII: cmd.exe reads it in the console code page, which would garble any other text.
setlocal
cd /d "%~dp0"
title DSTN - DASTAN
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dstn_start.ps1" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%
