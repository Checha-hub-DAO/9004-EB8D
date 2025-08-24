# C11_AUTOMATION_starter

Три скрипти для швидкого запуску автоматизації:
- `c11_focus_auto.ps1` — авто-пріоритизація → `C06_dev/FOCUS_AUTO.md`
- `c11_report_auto.ps1` — авто-звіт → `C07_dev/REPORT_AUTO.md`
- `c11_backup_sync.ps1` — бекап + тест відновлення (+опц. rclone)

## Використання
1. Розпакуйте папку `C11_AUTOMATION_starter` у `C:\CHECHA_CORE\C11_AUTOMATION\`.
2. Запустіть у PowerShell:
   - `./c11_backup_sync.ps1`
   - `./c11_focus_auto.ps1`
   - `./c11_report_auto.ps1`
3. Перевірте файли у `C06_dev` і `C07_dev`, після чого злийте у прод:
   - `Copy-Item C06_dev\FOCUS_AUTO.md C06\FOCUS.md -Force`
   - `Copy-Item C07_dev\REPORT_AUTO.md C07\REPORT.md -Force`

## Планувальник (приклад)
```
$root = "C:\CHECHA_CORE"
schtasks /Create /SC DAILY /TN "CHECHA_BACKUP" /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_backup_sync.ps1`"" /ST 08:30
schtasks /Create /SC DAILY /TN "CHECHA_FOCUS_AUTO" /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_focus_auto.ps1`"" /ST 19:10
schtasks /Create /SC DAILY /TN "CHECHA_REPORT_AUTO" /TR "powershell -NoProfile -File `"$root\C11_AUTOMATION\c11_report_auto.ps1`"" /ST 19:20
```
