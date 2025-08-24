# c11_write_checklist.ps1
param([string]$Root = "C:\CHECHA_CORE")

$ErrorActionPreference = "Stop"

# Paths
$devDir   = Join-Path $Root "C06_dev"
$logDir   = Join-Path $Root "C03"
$logPath  = Join-Path $logDir "LOG.md"
$outPath  = Join-Path $devDir "CHECKLIST_PREP.md"

# Ensure folders exist (no changes to prod content files)
New-Item -ItemType Directory -Force -Path $devDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Create LOG.md if absent
if (-not (Test-Path $logPath)) { "" | Set-Content -Path $logPath -Encoding UTF8 }

# Checklist content (today, dev only)
$checklist = @"
# ✅ Чек-лист “Підготовка до авто-режиму” (сьогодні)

## A. Структура та файли
- [ ] Створити папки: `C06_dev/`, `C07_dev/`, `C11_AUTOMATION/`
- [ ] Перевірити наявність: `C03/LOG.md`, `C06/FOCUS.md`, `C07/REPORT.md`
- [ ] Розпакувати `C11_AUTOMATION_starter.zip` у `C11_AUTOMATION/`

## B. Тест бекапу й відновлення
- [ ] Запустити: `powershell -NoProfile -File .\\c11_backup_sync.ps1`
- [ ] Перевірити ZIP у `C05/Archive/YYYY-MM-DD/`
- [ ] Переконатися, що у `C03/LOG.md` є `[AUTO] backup ... + restore check OK`

## C. Авто-пріоритизація (dev)
- [ ] Запустити: `powershell -NoProfile -File .\\c11_focus_auto.ps1`
- [ ] Перевірити `C06_dev/FOCUS_AUTO.md` (TOP-3, Backlog)
- [ ] У `C03/LOG.md` є `[AUTO] FOCUS_AUTO.md updated`

## D. Авто-звіт (dev)
- [ ] Запустити: `powershell -NoProfile -File .\\c11_report_auto.ps1`
- [ ] Перевірити `C07_dev/REPORT_AUTO.md` (підрахунки, останні 10 подій)
- [ ] У `C03/LOG.md` є `[AUTO] REPORT_AUTO.md updated`

## E. Контроль безпеки
- [ ] Не робити merge у прод сьогодні
- [ ] Зробити ручний контрольний ZIP “точка відкату”

## F. Підготовка до автозапуску
- [ ] Підготувати команди для планувальника з README
- [ ] Визначити години автозапуску, але не запускати сьогодні

## G. Журнал і нотатка
- [ ] Додати у `C03/LOG.md` запис `[PREP]`
- [ ] Створити `C07_dev/REPORT_NOTE.md` з висновком про підготовку
"@

# Write checklist (idempotent)
$checklist | Set-Content -Path $outPath -Encoding UTF8

# Append a PREP log entry
$logEntry = "| $(Get-Date 'yyyy-MM-dd HH:mm:ss') | c11_write_checklist | OK | [PREP] CHECKLIST_PREP.md created in C06_dev (no prod changes)"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "Checklist written to $outPath and PREP logged to $logPath."
