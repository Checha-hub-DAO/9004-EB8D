@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ===== Config =====
set "ROOT=C:\CHECHA_CORE"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "BACKUP=%ROOT%\C11_AUTOMATION\c11_backup_sync_fixed.ps1"
set "HEALTH=%ROOT%\C11_AUTOMATION\c11_health_check_alert.ps1"
set "PREPNORM=%ROOT%\C11_AUTOMATION\c11_prep_normalize.ps1"
set "EOD=%ROOT%\C11_AUTOMATION\c11_eod.ps1"
set "LOGDIR=%ROOT%\C03"
for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd\")"') do set "DATESTAMP=%%i"
set "LOG=%LOGDIR%\NIGHT_CHAIN_%DATESTAMP%.log"
REM ===================

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

echo ================= NIGHT CHAIN START ================= 1>&2
echo [START] %date% %time%  >> "%LOG%"
echo ROOT=%ROOT% >> "%LOG%"

REM Helper to run a PS script with console + file logging
set "TEE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command"
set "ENVLOG=$env:LOG"

REM 1) Backup
echo. | (echo [%%date%% %%time%%] Backup starting...) & echo [BACKUP] start >> "%LOG%"
%TEE% "& { & '%BACKUP%' 2>&1 | Tee-Object -FilePath %ENVLOG% -Append }"
set "RC_BACKUP=!ERRORLEVEL!"
echo [BACKUP] rc=!RC_BACKUP! >> "%LOG%"
echo Backup finished, rc=!RC_BACKUP!

REM 2) Health-check (alerts)
echo. | (echo [%%date%% %%time%%] Health-check starting...) & echo [HEALTH] start >> "%LOG%"
%TEE% "& { & '%HEALTH%' 2>&1 | Tee-Object -FilePath %ENVLOG% -Append }"
set "RC_HEALTH=!ERRORLEVEL!"
if not "!RC_HEALTH!"=="0" (
  echo [HEALTH] WARN rc=!RC_HEALTH! >> "%LOG%"
  echo WARN detected by health-check (rc=!RC_HEALTH!). See ALERTS.md
) else (
  echo [HEALTH] OK rc=!RC_HEALTH! >> "%LOG%"
  echo Health OK.
)

REM 3) PREP normalize (run even if WARN to keep files clean)
echo. | (echo [%%date%% %%time%%] PREP normalize...) & echo [PREP] normalize start >> "%LOG%"
%TEE% "& { & '%PREPNORM%' 2>&1 | Tee-Object -FilePath %ENVLOG% -Append }"
set "RC_PREP=!ERRORLEVEL!"
echo [PREP] rc=!RC_PREP! >> "%LOG%"

REM 4) EOD summary (always run)
echo. | (echo [%%date%% %%time%%] EOD starting...) & echo [EOD] start >> "%LOG%"
%TEE% "& { & '%EOD%' 2>&1 | Tee-Object -FilePath %ENVLOG% -Append }"
set "RC_EOD=!ERRORLEVEL!"
echo [EOD] rc=!RC_EOD! >> "%LOG%"

echo [END] %date% %time%  >> "%LOG%"
echo NIGHT CHAIN done. (backup=!RC_BACKUP!, health=!RC_HEALTH!, prep=!RC_PREP!, eod=!RC_EOD!)
exit /b !RC_HEALTH!
