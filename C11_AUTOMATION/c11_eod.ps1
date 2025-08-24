# c11_eod.ps1 (ASCII-safe) - End Of Day helper
param([string]$Root = "C:\CHECHA_CORE")

$ErrorActionPreference = "SilentlyContinue"

# ---- Paths ----
$logPath     = Join-Path $Root "C03\LOG.md"
$alertsPath  = Join-Path $Root "C03\ALERTS.md"
$dirC03      = Join-Path $Root "C03"

# Ensure dirs/files exist
New-Item -ItemType Directory -Force -Path $dirC03 | Out-Null
if (-not (Test-Path $logPath))    { New-Item -ItemType File -Path $logPath    | Out-Null }
if (-not (Test-Path $alertsPath)) { New-Item -ItemType File -Path $alertsPath | Out-Null }

# ---- Time ----
$now        = Get-Date
$stampLong  = $now.ToString("yyyy-MM-dd HH:mm:ss")
$dayDash    = $now.ToString("yyyy-MM-dd")
$dayCompact = $now.ToString("yyyyMMdd")

# ---- Export today's WARN lines ----
$warnOut = Join-Path $dirC03 ("WARN_" + $dayCompact + ".log")
$todayWarn = @()
Get-Content $logPath | ForEach-Object {
    if ($_ -match "^\|\s*$dayDash\s+" -and $_ -match "\|\s+WARN\s+\|") { $todayWarn += $_ }
}
if ($todayWarn.Count -gt 0) {
    $todayWarn | Set-Content -Path $warnOut -Encoding UTF8
} else {
    "No WARN entries for " + $dayDash | Set-Content -Path $warnOut -Encoding UTF8
}

# ---- Rotate ALERTS.md for the day ----
if (Test-Path $alertsPath) {
    $alertsSize = (Get-Item $alertsPath).Length
    # Save only if has content
    if ($alertsSize -gt 0) {
        $alertsArchive = Join-Path $dirC03 ("ALERTS_" + $dayCompact + ".md")
        # Make unique name if exists
        if (Test-Path $alertsArchive) {
            $i = 1
            while (Test-Path ($alertsArchive -replace '\.md$', "_$i.md")) { $i++ }
            $alertsArchive = $alertsArchive -replace '\.md$', "_$i.md"
        }
        Move-Item -Path $alertsPath -Destination $alertsArchive -Force
    }
    # Create fresh ALERTS.md
    New-Item -ItemType File -Path $alertsPath -Force | Out-Null
}

# ---- Count today's OK/WARN for summary ----
$todayOK = 0; $todayWARN = 0
Get-Content $logPath | ForEach-Object {
    if ($_ -match "^\|\s*$dayDash\s+") {
        if ($_ -match "\|\s+OK\s+\|")   { $todayOK++ }
        if ($_ -match "\|\s+WARN\s+\|") { $todayWARN++ }
    }
}

# ---- Append EOD line to LOG.md ----
$summary = "[EOD] ok=" + $todayOK + "; warn=" + $todayWARN + "; alerts_rotated=" + (Get-Date -Format "yyyyMMdd")
Add-Content -Path $logPath -Value ("| " + $stampLong + " | c11_eod | OK | " + $summary) -Encoding UTF8

Write-Host "EOD complete. WARN exported to: $warnOut"
