param(
    [string]$Root = "D:\CHECHA_CORE"
)

function Write-Step($msg) { Write-Host ("[SELFTEST] " + $msg) }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null } }

$ok = $true
$errors = @()
$now = Get-Date
$healthDir = Join-Path $Root "C03\HEALTH"
Ensure-Dir -Path $healthDir
$report = Join-Path $healthDir ("SELFTEST_" + $now.ToString("yyyy-MM-dd_HH-mm") + ".md")

# Basic checks
$mustDirs = @("C01\INBOX","C03","C05\Archive","C07")
foreach ($rel in $mustDirs) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path $p)) { $ok = $false; $errors += ("Missing dir: " + $rel) }
}

# Tasks exist?
$taskNames = @("CHECHA_CORE — INBOX Guardian","CHECHA_CORE — KPI Report","CHECHA_CORE — JSON Report","CHECHA_CORE — Auto-Archive","CHECHA_CORE — Retention")
foreach ($t in $taskNames) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if (-not $task) { $ok = $false; $errors += ("ScheduledTask missing: " + $t) }
}

# checha-report JSON
try {
    $tmpJson = Join-Path $healthDir "SELFTEST_LATEST_REPORT.json"
    Import-Module (Join-Path $Root "tools\checha\checha.psm1") -Force -ErrorAction SilentlyContinue
    checha-report -Root $Root -Json -OutFile $tmpJson
    if (-not (Test-Path $tmpJson)) { $ok = $false; $errors += "checha-report failed to produce JSON" }
} catch { $ok = $false; $errors += ("checha-report exception: " + $_.Exception.Message) }

# Post-archive presence (after 20:15)
try {
    $cfgPath = Join-Path $Root "config\ChechaCore.config.json"
    $archiveTime = "20:10"
    if (Test-Path $cfgPath) {
        $cfg = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json
        if ($cfg.schedules.archive) { $archiveTime = $cfg.schedules.archive }
    }
    $afterCheck = (Get-Date) -gt (Get-Date $archiveTime).AddMinutes(5)
    if ($afterCheck) {
        $todayDir = Join-Path $Root ("C05\Archive" + (Get-Date).ToString("yyyy-MM-dd"))
        if (-not (Test-Path $todayDir)) { $ok = $false; $errors += "No archive folder for today (after archive window)" }
    }
} catch {}


# --- DIST / updater presence checks ---
try {
    $distDir = Join-Path $Root "C03\DIST"
    if (-not (Test-Path $distDir)) {
        $warns += "DIST folder missing: C03\DIST"
    } else {
        $latestBundle = Get-ChildItem -LiteralPath $distDir -File -Filter "ChechaCore_v*.zip" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestBundle) {
            $shaSide = $latestBundle.FullName + ".sha256"
            if (Test-Path $shaSide) {
                try {
                    $expected = (Get-Content -Raw -LiteralPath $shaSide) -split '\s+' | Select-Object -First 1
                    $actual = (Get-FileHash -LiteralPath $latestBundle.FullName -Algorithm SHA256).Hash
                    if ($expected -ne $actual) { $warns += ("Bundle SHA256 mismatch: " + $latestBundle.Name) }
                } catch { $warns += ("Bundle hash error: " + $latestBundle.Name + " — " + $_.Exception.Message) }
            } else {
                $warns += ("Bundle has no .sha256: " + $latestBundle.Name)
            }
        } else {
            $warns += "No ChechaCore_v*.zip found in C03\DIST"
        }
    }
} catch { $warns += ("DIST check error: " + $_.Exception.Message) }

# Updater alias presence
try {
    $updBat = Join-Path $Root "scripts\checha-update.bat"
    if (-not (Test-Path $updBat)) { $warns += "Updater alias missing: scripts\checha-update.bat" }
} catch { $warns += ("Updater check error: " + $_.Exception.Message) }

# Write report
$lines = @()
$lines += "# CHECHA_CORE Self-Test"
$lines += "- Time: " + $now.ToString("yyyy-MM-dd HH:mm:ss")
$lines += "- Root: " + $Root
$lines += "- Result: " + ($(if ($ok) {"OK"} else {"FAIL"}))
if ($errors.Count -gt 0) {
  $lines += ""
  $lines += "## Issues"
  foreach ($e in $errors) { $lines += ("- " + $e) }
}
if ($warns.Count -gt 0) {
  $lines += ""
  $lines += "## Warnings"
  foreach ($w in $warns) { $lines += ("- " + $w) }
}
Set-Content -Path $report -Value ($lines -join "`r`n") -Encoding UTF8
Write-Step ("Report -> " + $report)

# Log
$logDir = Join-Path $Root "C03"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logPath = Join-Path $logDir "LOG.md"
if (-not (Test-Path $logPath)) { "# New LOG.md (init)" | Out-File -FilePath $logPath -Encoding UTF8 }
$line = "| {0} | selftest | {1} |" -f ($now.ToString("yyyy-MM-dd HH:mm:ss")), ($(if ($ok) {"OK"} else {"FAIL"}))
Add-Content -Path $logPath -Value $line -Encoding UTF8
if ($warns.Count -gt 0) { Add-Content -Path $logPath -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | selftest-warn | " + ($warns -join "; ") + " |") -Encoding UTF8 }

if (-not $ok) { exit 1 } else { exit 0 }
