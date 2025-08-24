# c11_health_check_alert.ps1 (ASCII-safe, with alerts)
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

# Checks
$errors = @()
$notes  = @()

# 1) Archive exists and contains at least one zip
$arcOk = $false
if (Test-Path $arcDir) {
    $zips = Get-ChildItem $arcDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($zips.Count -gt 0) {
        $arcOk = $true
        $notes += "archive zip=" + $zips[0].FullName
    } else {
        $errors += "no zip in archive dir"
    }
} else {
    $errors += "archive dir missing"
}

# 2) Focus and Report updated today
$focusOk  = (Test-Path $focusPath)  -and ((Get-Item $focusPath).LastWriteTime.Date  -eq $now.Date)
$reportOk = (Test-Path $reportPath) -and ((Get-Item $reportPath).LastWriteTime.Date -eq $now.Date)

if ($focusOk) { $notes += "focus updated" } else { $errors += "focus not updated today" }
if ($reportOk){ $notes += "report updated"} else { $errors += "report not updated today" }

# 3) Scheduled tasks present and Ready
function TaskReady($name){
    $q = schtasks /Query /TN $name /FO LIST /V 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    return ($q -join "`n") -match "Status:\s+Ready"
}
$focusTaskOk  = TaskReady "CHECHA_FOCUS_AUTO"
$reportTaskOk = TaskReady "CHECHA_REPORT_AUTO"
$backupTaskOk = TaskReady "CHECHA_BACKUP"

if ($focusTaskOk)  { $notes += "task FOCUS ready" }  else { $errors += "task FOCUS missing/not ready" }
if ($reportTaskOk) { $notes += "task REPORT ready" } else { $errors += "task REPORT missing/not ready" }
if ($backupTaskOk) { $notes += "task BACKUP ready" } else { $errors += "task BACKUP missing/not ready" }

# Compose status
$status  = if ($errors.Count -eq 0) { "OK" } else { "WARN" }
$summary = if ($errors.Count -eq 0) { "[HEALTH] " + ($notes -join "; ") } else { "[HEALTH] issues: " + ($errors -join "; ") + " | notes: " + ($notes -join "; ") }

# Ensure log files exist
if (-not (Test-Path $logPath))    { New-Item -ItemType File -Path $logPath    | Out-Null }
if (-not (Test-Path $alertsPath)) { New-Item -ItemType File -Path $alertsPath | Out-Null }

# Write to LOG.md
Add-Content -Path $logPath -Value ("| " + $nowStr + " | c11_health_check | " + $status + " | " + $summary) -Encoding UTF8

# On WARN: append to ALERTS.md, beep, and exit 1 so Task Scheduler flags it
if ($status -ne "OK") {
    $alertLine = "| " + $nowStr + " | ALERT | " + $summary
    Add-Content -Path $alertsPath -Value $alertLine -Encoding UTF8

    try {
        [console]::beep(1000,400)
        Start-Sleep -Milliseconds 150
        [console]::beep(800,400)
        Start-Sleep -Milliseconds 150
        [console]::beep(1200,500)
    } catch {}

    Write-Host ("Status: " + $status)
    Write-Host ("Summary: " + $summary)
    exit 1
}

Write-Host ("Status: " + $status)
Write-Host ("Summary: " + $summary)
exit 0
