@echo off
chcp 65001 >nul
setlocal
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\log_rotate.ps1" -Path "C:\CHECHA_CORE\logs\vault_bot_weekly.log" -MaxKB 512 -Keep 5
cd /d C:\CHECHA_CORE\C11
echo ==== START %date% %time% ====>>"C:\CHECHA_CORE\logs\vault_bot_weekly.log"
py "C:\CHECHA_CORE\C11\vault_bot.py" --items "C:\CHECHA_CORE\C11\inputs\items.csv" --zip --items-clear --release auto --release-prefix v2.3 >>"C:\CHECHA_CORE\logs\vault_bot_weekly.log" 2>&1
echo ExitCode=%ERRORLEVEL% >>"C:\CHECHA_CORE\logs\vault_bot_weekly.log"
echo ==== END %date% %time% ====>>"C:\CHECHA_CORE\logs\vault_bot_weekly.log"

REM === GIT AUTO-PUBLISH ===
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\push_repo.ps1" -Repo "C:\CHECHA_CORE"
endlocal

