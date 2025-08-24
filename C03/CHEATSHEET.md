# CHECHA_CORE — CHEATSHEET (щодень / швидкі команди)

> Мета: мати під рукою 1 сторінку команд. Вважай, що ROOT = `D:\CHECHA_CORE`.

---

## 1) Інсталяція / оновлення (v19)
```
PowerShell -ExecutionPolicy Bypass -File ".\ChechaCore-Deploy-INSTALLER-v19.ps1" ^
  -Root "D:\CHECHA_CORE" ^
  -WatchC -CreateSymlink ^
  -ScheduleGuardian -GuardianTime "20:00" ^
  -ScheduleKPI -KpiTime "20:05" ^
  -ScheduleJsonReport -JsonReportTime "20:06" ^
  -ScheduleArchive -ArchiveTime "20:10" ^
  -ScheduleRetention -RetentionTime "20:20" ^
  -ScheduleSelfTest -SelfTestTime "22:30" ^
  -ScheduleLogRotate -LogRotateTime "00:05" ^
  -WeekdaysOnly ^
  -AutoLog
```

**Перемкнути будні/щодня:**
1) Відкрити `config\ChechaCore.config.json`, змінити `schedules.weekdays_only`.  
2) Застосувати:
```
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Apply-Config.ps1" -ConfigPath "D:\CHECHA_CORE\config\ChechaCore.config.json"
```

---

## 2) Пароль і шифрування (ENV-only)
```
# задати пароль (користувацький або машинний)
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Set-Secret.ps1"
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Set-Secret.ps1" -Machine

# увімкнути шифрування в конфізі (без зберігання пароля)
"archive": { "zip": true, "zip_encrypt": true, "offsite": { "enabled": true, "path": "E:\\CHECHA_BACKUPS" } }
```
> Перевір: є `7z.exe`. Якщо нема — буде звичайний ZIP.

---

## 3) Запустити вручну (разово)
```
# KPI / Guardian / JSON / Archive / Retention / Self-Test / LogRotate (три способи)

# A) ТИМЧАСОВО запустити задачу планувальника
Start-ScheduledTask -TaskName "CHECHA_CORE — KPI Report"
Start-ScheduledTask -TaskName "CHECHA_CORE — INBOX Guardian"
Start-ScheduledTask -TaskName "CHECHA_CORE — JSON Report"
Start-ScheduledTask -TaskName "CHECHA_CORE — Auto-Archive"
Start-ScheduledTask -TaskName "CHECHA_CORE — Retention"
Start-ScheduledTask -TaskName "CHECHA_CORE — Self-Test"
Start-ScheduledTask -TaskName "CHECHA_CORE — LogRotate"

# B) Запустити напряму скрипти (де є)
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Emit-JSON-Report.ps1" -Root "D:\CHECHA_CORE"
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Auto-Archive.ps1" -Root "D:\CHECHA_CORE"
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Retention-Plus.ps1" -Root "D:\CHECHA_CORE" -DryRun
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-SelfTest.ps1" -Root "D:\CHECHA_CORE"
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Log-Rotate.ps1" -Root "D:\CHECHA_CORE" -Force

# C) JSON‑зріз через модуль (якщо імпортований)
checha-report -Root "D:\CHECHA_CORE" -Json -OutFile "D:\CHECHA_CORE\C07\LATEST_REPORT.json"
```

---

## 4) Перевірка офсайту (SHA256)
```
$day = (Get-Date).ToString("yyyy-MM-dd")
$src = "D:\CHECHA_CORE\C05\Archive\$day"; $off = "E:\CHECHA_BACKUPS\$day"
function ShaFromSidecar($p){ if(Test-Path $p){ return ((Get-Content -Raw -LiteralPath $p) -split '\s+')[0] } $null }

# JSON
$srcJson = Join-Path $src ("REPORT_" + $day + ".json"); $offJson = Join-Path $off ("REPORT_" + $day + ".json")
$srcSha = ShaFromSidecar ($srcJson + ".sha256"); if(-not $srcSha){ $srcSha = (Get-FileHash $srcJson -Algorithm SHA256).Hash }
$offSha = (Get-FileHash $offJson -Algorithm SHA256).Hash
"{0} JSON SHA256: src={1} off={2} equal={3}" -f $day,$srcSha,$offSha,($srcSha -eq $offSha)

# Архів (.7z/.zip)
$srcArc = Get-ChildItem -LiteralPath $src -File -Filter "SNAPSHOT_*.*" | ? { $_.Extension -in ".7z",".zip" } | Select-Object -First 1
$offArc = Join-Path $off $srcArc.Name
$srcASha = ShaFromSidecar ($srcArc.FullName + ".sha256"); if(-not $srcASha){ $srcASha = (Get-FileHash $srcArc.FullName -Algorithm SHA256).Hash }
$offASha = (Get-FileHash $offArc -Algorithm SHA256).Hash
"{0} ARCH SHA256: src={1} off={2} equal={3}" -f $day,$srcASha,$offASha,($srcASha -eq $offASha)
```
> Якщо `equal=False` — шукай `offsite-verify | MISMATCH` у `C03\LOG.md`.

---

## 5) Діагностика швидко
```
# Список задач і останні результати
Get-ScheduledTask | ? { $_.TaskName -like "CHECHA_CORE*" } | Select TaskName,State
Get-ScheduledTaskInfo -TaskName "CHECHA_CORE — Auto-Archive"

# Self‑Test
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-SelfTest.ps1" -Root "D:\CHECHA_CORE"

# Логи
Get-Content "D:\CHECHA_CORE\C03\LOG.md" -Tail 60
```

---

## 6) Ретеншн / ротація
```
# Dry‑run: що буде видалено
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Retention-Plus.ps1" -Root "D:\CHECHA_CORE" -DryRun

# Форс‑ротація LOG зараз (не чекаючи 1 числа)
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Log-Rotate.ps1" -Root "D:\CHECHA_CORE" -Force
```

---

## 7) Корисні місця
- `C01\INBOX` — вхідні матеріали (працюємо з префіксами `_WIP`).  
- `C03\LOG.md` — основний лог подій.  
- `C05\Archive\YYYY-MM-DD` — щоденні архіви (`REPORT_*.json`, `SNAPSHOT_*.7z/.zip`, `.sha256`, `MANIFEST_*`).  
- `C07\LATEST_REPORT.json` — актуальний JSON‑зріз.

---

## 8) Налаштування, що часто чіпаємо
`config\ChechaCore.config.json`:
- `schedules`: часи задач (guardian/kpi/jsonreport/archive/retention/selftest/logrotate), `weekdays_only`.  
- `archive.zip` / `archive.zip_encrypt` / `archive.offsite.path`  
Після змін — **Apply-Config** (див. п.1).


---

## 11) Оновлення (bundle)
```
# Опублікувати ZIP локально (і в офсайт, якщо ввімкнено)
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Publish-Bundle.ps1" -Root "D:\CHECHA_CORE" -BundlePath "C:\Path\to\ChechaCore_v21_2_full_bundle.zip"

# Оновитись з останнього ZIP у C03\DIST
PowerShell -ExecutionPolicy Bypass -File "D:\CHECHA_CORE\scripts\ChechaCore-Update-From-Bundle.ps1" -Root "D:\CHECHA_CORE"

# (Опційно) щоденна перевірка C03\DIST о 03:30
PowerShell -ExecutionPolicy Bypass -File ".\ChechaCore-Deploy-INSTALLER-v21.2.ps1" -Root "D:\CHECHA_CORE" -ScheduleUpdateCheck -UpdateCheckTime "03:30"
```
