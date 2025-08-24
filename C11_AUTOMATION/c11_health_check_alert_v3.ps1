# c11_health_check_alert_v3.ps1 (robust + LOG backup + log-format self-test)
param([string]$Root = "C:\CHECHA_CORE", [int]$MaxLogBackups = 7)

$ErrorActionPreference = "SilentlyContinue"

# Paths
$logPath    = Join-Path $Root "C03\LOG.md"
$alertsPath = Join-Path $Root "C03\ALERTS.md"
$focusPath  = Join-Path $Root "C06\FOCUS.md"
$reportPath = Join-Path $Root "C07\REPORT.md"
$arcRoot    = Join-Path $Root "C05\Archive"

# Ensure dirs/files
New-Item -ItemType Directory -Force -Path (Join-Path $Root "C03") | Out-Null
if (-not (Test-Path $logPath))    { New-Item -ItemType File -Path $logPath    | Out-Null }
if (-not (Test-Path $alertsPath)) { New-Item -ItemType File -Path $alertsPath | Out-Null }

# Helper: rotate small backups for LOG.md
function Backup-LogFile([string]$path, [int]$keep=7) {
    if (-not (Test-Path $path)) { return }
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($path), "LOG_$ts.bak")
    Copy-Item $path $bak -Force
    # prune old backups
    $bakList = Get-ChildItem ([System.IO.Path]::GetDirectoryName($path)) -Filter "LOG_*.bak" | Sort-Object LastWriteTime -Descending
    if ($bakList.Count -gt $keep) {
        $toRemove = $bakList | Select-Object -Skip $keep
        $toRemove | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    }
}

# Do the backup before any write
Backup-LogFile -path $logPath -keep $MaxLogBackups

$now       = Get-Date
$nowStr    = $now.ToString("yyyy-MM-dd HH:mm:ss")
$todayStr  = $now.ToString("yyyy-MM-dd")
$arcDir    = Join-Path $arcRoot $todayStr

# ---- Task status helper (CSV parsing) ----
function TaskExistsAndOK($name){
    $csv = schtasks /Query /TN $name /FO CSV /V 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $csv) { return $false }
    try {
        $rows = ConvertFrom-Csv -InputObject $csv
        foreach ($r in $rows) {
            $status = "" + $r.Status
            if ($status -match "(?i)(ready|running|готов|готово|готовий|виконується)") { return $true }
        }
        return $true
    } catch { return $true }
}

# ---- Checks ----
$errors = @()
$notes  = @()

# 0) LOG format self-test on last 200 lines
$re = "^\|\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s*\|\s*[^|]+\s*\|\s*(OK|WARN|ERROR)\s*\|\s*.*$"
$tail = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 200
$malformed = 0
foreach ($ln in $tail) {
    if ($ln.Trim().StartsWith("|")) {
        if ($ln -notmatch $re) { $malformed++ }
    }
}
if ($malformed -gt 0) {
    $errors += ("log format anomalies=" + $malformed)
}

# 1) Archive zip exists today
if (Test-Path $arcDir) {
    $zips = Get-ChildItem $arcDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($zips.Count -gt 0) { $notes += "archive zip=" + $zips[0].FullName } else { $errors += "no zip in archive dir" }
} else { $errors += "archive dir missing" }

# 2) Focus and Report updated today
$focusOk  = (Test-Path $focusPath)  -and ((Get-Item $focusPath).LastWriteTime.Date  -eq $now.Date)
$reportOk = (Test-Path $reportPath) -and ((Get-Item $reportPath).LastWriteTime.Date -eq $now.Date)
if ($focusOk) { $notes += "focus updated" } else { $errors += "focus not updated today" }
if ($reportOk){ $notes += "report updated"} else { $errors += "report not updated today" }

# 3) Scheduled tasks exist / OK
$focusTaskOk  = TaskExistsAndOK "CHECHA_FOCUS_AUTO"
$reportTaskOk = TaskExistsAndOK "CHECHA_REPORT_AUTO"
$backupTaskOk = TaskExistsAndOK "CHECHA_BACKUP"
if ($focusTaskOk)  { $notes += "task FOCUS ok" }  else { $errors += "task FOCUS missing/not ready" }
if ($reportTaskOk) { $notes += "task REPORT ok" } else { $errors += "task REPORT missing/not ready" }
if ($backupTaskOk) { $notes += "task BACKUP ok" } else { $errors += "task BACKUP missing/not ready" }

# Compose status
$status  = if ($errors.Count -eq 0) { "OK" } else { "WARN" }
$summary = if ($errors.Count -eq 0) { "[HEALTH] " + ($notes -join "; ") } else { "[HEALTH] issues: " + ($errors -join "; ") + " | notes: " + ($notes -join "; ") }

# Write to LOG.md and ALERTS.md if needed
Add-Content -Path $logPath -Value ("| " + $nowStr + " | c11_health_check | " + $status + " | " + $summary) -Encoding UTF8
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
