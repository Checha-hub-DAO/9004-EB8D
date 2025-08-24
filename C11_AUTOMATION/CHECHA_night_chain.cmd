@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ===== Config =====
set "ROOT=C:\CHECHA_CORE"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "BACKUP=%ROOT%\C11_AUTOMATION\c11_backup_sync_fixed.ps1"
set "HEALTH=%ROOT%\C11_AUTOMATION\c11_health_check_alert.ps1"
set "EOD=%ROOT%\C11_AUTOMATION\c11_eod.ps1"
set "ALERTS=%ROOT%\C03\ALERTS.md"
REM ===================

echo [%%date%% %%time%%] NIGHT CHAIN: backup -> health -> EOD

REM 1) Backup
echo [%%date%% %%time%%] Backup starting...
%PS% -File "%BACKUP%"
set "RC_BACKUP=!ERRORLEVEL!"
echo [%%date%% %%time%%] Backup finished with rc=!RC_BACKUP!

REM 2) Health-check (alerts)
echo [%%date%% %%time%%] Health-check starting...
%PS% -File "%HEALTH%"
set "RC_HEALTH=!ERRORLEVEL!"
if not "!RC_HEALTH!"=="0" (
  echo [%%date%% %%time%%] WARN detected by health-check (rc=!RC_HEALTH!).
  if exist "%ALERTS%" start notepad.exe "%ALERTS%"
) else (
  echo [%%date%% %%time%%] Health OK.
)

REM 3) EOD summary
echo [%%date%% %%time%%] EOD starting...
%PS% -File "%EOD%"
set "RC_EOD=!ERRORLEVEL!"
echo [%%date%% %%time%%] EOD finished with rc=!RC_EOD!

echo [%%date%% %%time%%] NIGHT CHAIN done. (backup=!RC_BACKUP!, health=!RC_HEALTH!, eod=!RC_EOD!)
exit /b !RC_HEALTH!
