# c11_backup_sync.ps1 (fixed, robust, ASCII-safe)
param([string]$Root = "C:\CHECHA_CORE")

$ErrorActionPreference = "Stop"

# Paths
$arcRoot = Join-Path $Root "C05\Archive"
$todayDir = (Get-Date -Format "yyyy-MM-dd")
$arcDir  = Join-Path $arcRoot $todayDir

# Ensure archive dir exists
New-Item -ItemType Directory -Force -Path $arcDir | Out-Null

# Build filenames
$stamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$zipName = "CHECHA_CORE_" + $stamp + ".zip"
$zipPath = Join-Path $arcDir $zipName

# Create ZIP OUTSIDE the source tree to avoid locking the file while zipping
$tempZip = Join-Path $env:TEMP ("CHECHA_CORE_" + $stamp + ".zip")

# Log path
$logPath = Join-Path $Root "C03\LOG.md"
if (-not (Test-Path $logPath)) { New-Item -ItemType File -Path $logPath | Out-Null }

# Create ZIP with retries (in case antivirus scans TEMP)
Add-Type -AssemblyName System.IO.Compression.FileSystem

$maxRetries = 3
$retry = 0
$zipOk = $false
while (-not $zipOk -and $retry -lt $maxRetries) {
    try {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
        # Build archive from Root to TEMP
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Root, $tempZip)
        $zipOk = $true
    } catch {
        Start-Sleep -Seconds 2
        $retry++
    }
}

if (-not $zipOk) {
    $logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_backup_sync | ERROR | Backup failed after retries (temp zip)"
    Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    throw "Backup failed after retries when creating TEMP zip."
}

# Move completed zip into Archive folder with a unique name if needed
if (Test-Path $zipPath) {
    # Find a unique name by appending a counter
    $i = 1
    do {
        $zipPath = Join-Path $arcDir ("CHECHA_CORE_" + $stamp + "_" + $i + ".zip")
        $i++
    } while (Test-Path $zipPath)
}
Move-Item -Path $tempZip -Destination $zipPath -Force

# Test restore to TEMP
$testDir = Join-Path $env:TEMP ("CHECHA_RESTORE_" + $stamp)
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $testDir)

# Simple validation: presence of core files
$ok = (Test-Path (Join-Path $testDir "C03\LOG.md")) -and (Test-Path (Join-Path $testDir "C06\FOCUS.md")) -and (Test-Path (Join-Path $testDir "C07\REPORT.md"))

# Optional: rclone upload if configured (remote 'gdrive:' must exist). Safe to skip if not present.
$rclone = (Get-Command rclone -ErrorAction SilentlyContinue)
if ($rclone) {
    try {
        & $rclone.Path copy "$zipPath" "gdrive:/DAO-GOGS/CHECHA_CORE_Archive/" --immutable --transfers 2 --checkers 4 | Out-Null
    } catch {
        # Do not fail the whole script if cloud copy fails
    }
}

# Cleanup restore test directory
try { Remove-Item -Recurse -Force $testDir } catch {}

# Write log entry
$status = if ($ok) { "OK" } else { "WARN" }
$msg = if ($ok) { "[AUTO] backup completed: $zipPath + restore check OK" } else { "[AUTO] backup completed: $zipPath, restore check WARN (missing core files)" }
Add-Content -Path $logPath -Value ("| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_backup_sync | " + $status + " | " + $msg) -Encoding UTF8

Write-Host "Backup saved to $zipPath. Restore check: $status"
