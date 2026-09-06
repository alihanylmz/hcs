@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_quote_checks.ps1" %*
exit /b %ERRORLEVEL%
