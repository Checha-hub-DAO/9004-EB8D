# CHECHA_CORE Operations — Quick Guide

## Daily
- **19:10** — `CHECHA_FOCUS_AUTO` → updates `C06_dev\FOCUS_AUTO.md`
- **19:20** — `CHECHA_REPORT_AUTO` → updates `C07_dev\REPORT_AUTO.md`
- **23:55** — `CHECHA_BACKUP` (night chain) → Backup → Health (alerts) → EOD
- **23:58** — `CHECHA_HEALTH_NIGHT` (optional if using the chain)
- **09:05** — `CHECHA_HEALTH_MORNING`

## Manual merge (dev → prod)
```powershell
Copy-Item C:\CHECHA_CORE\C06_dev\FOCUS_AUTO.md  C:\CHECHA_CORE\C06\FOCUS.md  -Force
Copy-Item C:\CHECHA_CORE\C07_dev\REPORT_AUTO.md C:\CHECHA_CORE\C07\REPORT.md -Force
Add-Content C:\CHECHA_CORE\C03\LOG.md "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | merge | OK | [AUTO] C06/C07 updated from *_AUTO.md"
```

## Backup (fixed) — manual run
```powershell
powershell -NoProfile -File C:\CHECHA_CORE\C11_AUTOMATION\c11_backup_sync_fixed.ps1
```

## Health-check (alerts)
- Script: `C11_AUTOMATION\c11_health_check_alert_v3.ps1`
- WARN ⇒ beeps + appends to `C03\ALERTS.md` + exits with code 1

## Night chain (cmd)
- `C11_AUTOMATION\CHECHA_night_chain.cmd`: Backup → Health → EOD; opens `ALERTS.md` on WARN

## EOD helper
```powershell
powershell -NoProfile -File C:\CHECHA_CORE\C11_AUTOMATION\c11_eod.ps1
```

## Task Scheduler — create under SYSTEM
```powershell
$root="C:\CHECHA_CORE"
schtasks /Create /SC DAILY /TN "CHECHA_BACKUP" /TR "`"$root\C11_AUTOMATION\CHECHA_night_chain.cmd`"" /ST 23:55 /RU "SYSTEM" /RL HIGHEST
schtasks /Create /SC DAILY /TN "CHECHA_FOCUS_AUTO"  /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_focus_auto_logic_plus_v3.ps1`"" /ST 19:10 /RU "SYSTEM" /RL HIGHEST
schtasks /Create /SC DAILY /TN "CHECHA_REPORT_AUTO" /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_report_auto_ascii.ps1`"" /ST 19:20 /RU "SYSTEM" /RL HIGHEST
schtasks /Create /SC DAILY /TN "CHECHA_HEALTH_MORNING" /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_health_check_alert_v3.ps1`"" /ST 09:05 /RU "SYSTEM" /RL HIGHEST
```

## Log format contract (to keep parsers happy)
```
| YYYY-MM-DD HH:MM:SS | <module> | OK|WARN|ERROR | <message>
```
- Example: `| 2025-08-13 22:40:25 | c11_backup_sync | OK | [AUTO] backup completed: ... + restore check OK`

## Recovery notes
- Backups stored under `C05\Archive\YYYY-MM-DD\CHECHA_CORE_YYYY-MM-DD_HH-MM-SS.zip`
- Quick restore test location: `%TEMP%\CHECHA_RESTORE_...`
