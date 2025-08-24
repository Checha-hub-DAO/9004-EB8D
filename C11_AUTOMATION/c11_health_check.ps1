# c11_health_check.ps1 (ASCII-safe)
param([string]$Root = "C:\CHECHA_CORE")

$ErrorActionPreference = "SilentlyContinue"

# Paths
$logPath   = Join-Path $Root "C03\LOG.md"
$focusPath = Join-Path $Root "C06\FOCUS.md"
$reportPath= Join-Path $Root "C07\REPORT.md"
$arcRoot   = Join-Path $Root "C05\Archive"

$today     = Get-Date
$todayStr  = $today.ToString("yyyy-MM-dd")
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
$focusOk = (Test-Path $focusPath) -and ((Get-Item $focusPath).LastWriteTime.Date -eq $today.Date)
$reportOk = (Test-Path $reportPath) -and ((Get-Item $reportPath).LastWriteTime.Date -eq $today.Date)

if ($focusOk) { $notes += "focus updated" } else { $errors += "focus not updated today" }
if ($reportOk){ $notes += "report updated"} else { $errors += "report not updated today" }

# 3) Scheduled tasks present
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
$status = if ($errors.Count -eq 0) { "OK" } else { "WARN" }
$summary = if ($errors.Count -eq 0) { "[HEALTH] " + ($notes -join "; ") } else { "[HEALTH] issues: " + ($errors -join "; ") + " | notes: " + ($notes -join "; ") }

# Log
if (-not (Test-Path $logPath)) { New-Item -ItemType File -Path $logPath | Out-Null }
Add-Content -Path $logPath -Value ("| " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | c11_health_check | " + $status + " | " + $summary) -Encoding UTF8

# Console output
Write-Host ("Status: " + $status)
Write-Host ("Summary: " + $summary)
