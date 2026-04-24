@echo off
setlocal

REM Common wrapper for double-click / BAT users.
REM Passes all arguments through to the PowerShell installer.

set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%agent-common-sync.ps1" %*
exit /b %ERRORLEVEL%
