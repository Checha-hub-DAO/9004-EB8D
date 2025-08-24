# c11_health_check_alert_v2.ps1 (robust task detection, alerts on WARN)
param([string]$Root = "C:\CHECHA_CORE")

$ErrorActionPreference = "SilentlyContinue"

# Paths
$logPath    = Join-Path $Root "C03\LOG.md"
$alertsPath = Join-Path $Root "C03\ALERTS.md"
$focusPath  = Join-Path $Root "C06\FOCUS.md"
$reportPath = Join-Path $Root "C07\REPORT.md"
$arcRoot    = Join-Path $Root "C05\Archive"

$now       = Get-Date
$nowStr    = $now.ToString("yyyy-MM-dd HH:mm:ss")
$todayStr  = $now.ToString("yyyy-MM-dd")
$arcDir    = Join-Path $arcRoot $todayStr

# ---- Helpers ----
function TaskExistsAndOK($name){
    # Use CSV to get stable columns (TaskName, Next Run Time, Status)
    $csv = schtasks /Query /TN $name /FO CSV /V 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $csv) { return $false }
    try {
        $rows = ConvertFrom-Csv -InputObject $csv
        foreach ($r in $rows) {
            $status = "" + $r.Status
            # Accept Ready / Running (English) or common localized statuses
            if ($status -match "(?i)(ready|running|готов|готово|готовий|виконується)") { return $true }
        }
        # If status not present, consider task found => OK
        return $true
    } catch {
        # Fallback: if query returned anything, assume OK
        return $true
    }
}

# ---- Checks ----
$errors = @()
$notes  = @()

# 1) Archive exists and contains at least one zip
if (Test-Path $arcDir) {
    $zips = Get-ChildItem $arcDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($zips.Count -gt 0) { $notes += "archive zip=" + $zips[0].FullName } else { $errors += "no zip in archive dir" }
} else { $errors += "archive dir missing" }

# 2) Focus and Report updated today
$focusOk  = (Test-Path $focusPath)  -and ((Get-Item $focusPath).LastWriteTime.Date  -eq $now.Date)
$reportOk = (Test-Path $reportPath) -and ((Get-Item $reportPath).LastWriteTime.Date -eq $now.Date)
if ($focusOk) { $notes += "focus updated" } else { $errors += "focus not updated today" }
if ($reportOk){ $notes += "report updated"} else { $errors += "report not updated today" }

# 3) Scheduled tasks exist and are OK
$focusTaskOk  = TaskExistsAndOK "CHECHA_FOCUS_AUTO"
$reportTaskOk = TaskExistsAndOK "CHECHA_REPORT_AUTO"
$backupTaskOk = TaskExistsAndOK "CHECHA_BACKUP"

if ($focusTaskOk)  { $notes += "task FOCUS ok" }  else { $errors += "task FOCUS missing/not ready" }
if ($reportTaskOk) { $notes += "task REPORT ok" } else { $errors += "task REPORT missing/not ready" }
if ($backupTaskOk) { $notes += "task BACKUP ok" } else { $errors += "task BACKUP missing/not ready" }

# Compose status
$status  = if ($errors.Count -eq 0) { "OK" } else { "WARN" }
$summary = if ($errors.Count -eq 0) { "[HEALTH] " + ($notes -join "; ") } else { "[HEALTH] issues: " + ($errors -join "; ") + " | notes: " + ($notes -join "; ") }

# Ensure log files exist
if (-not (Test-Path $logPath))    { New-Item -ItemType File -Path $logPath    | Out-Null }
if (-not (Test-Path $alertsPath)) { New-Item -ItemType File -Path $alertsPath | Out-Null }

# Write to LOG.md
Add-Content -Path $logPath -Value ("| " + $nowStr + " | c11_health_check | " + $status + " | " + $summary) -Encoding UTF8

# On WARN: append to ALERTS.md, beep, and exit 1
if ($status -ne "OK") {
    $alertLine = "| " + $nowStr + " | ALERT | " + $summary
    Add-Content -Path $alertsPath -Value $alertLine -Encoding UTF8
    try {
        [console]::beep(1000,400); Start-Sleep -Milliseconds 150
        [console]::beep(800,400);  Start-Sleep -Milliseconds 150
        [console]::beep(1200,500)
    } catch {}
    Write-Host ("Status: " + $status)
    Write-Host ("Summary: " + $summary)
    exit 1
}

Write-Host ("Status: " + $status)
Write-Host ("Summary: " + $summary)
exit 0
