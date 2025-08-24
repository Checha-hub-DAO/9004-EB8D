@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\scripts\DayStart_core.ps1"
set ERR=%ERRORLEVEL%
echo.
if %ERR% NEQ 0 ( echo [ERROR] DayStart exited with code %ERR% ) else ( echo [OK] DayStart finished successfully. )
pause
exit /b %ERR%
