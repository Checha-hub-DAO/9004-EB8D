@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ====== Config ======
set "ROOT=C:\CHECHA_CORE"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
REM =====================

echo [%%date%% %%time%%] Starting backup...
%PS% -File "%ROOT%\C11_AUTOMATION\c11_backup_sync_fixed.ps1"
set "BACKUP_RC=!ERRORLEVEL!"

echo [%%date%% %%time%%] Running health-check with alerts...
%PS% -File "%ROOT%\C11_AUTOMATION\c11_health_check_alert.ps1"
set "HEALTH_RC=!ERRORLEVEL!"

if not "!HEALTH_RC!"=="0" (
  echo [%%date%% %%time%%] WARN detected by health-check (exit code !HEALTH_RC!).
  if exist "%ROOT%\C03\ALERTS.md" start notepad.exe "%ROOT%\C03\ALERTS.md"
) else (
  echo [%%date%% %%time%%] Health OK.
)

echo [%%date%% %%time%%] Done. (backup rc=!BACKUP_RC!, health rc=!HEALTH_RC!)
exit /b !HEALTH_RC!
