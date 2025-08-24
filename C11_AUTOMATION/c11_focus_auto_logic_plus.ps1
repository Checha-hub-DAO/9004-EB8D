# c11_focus_auto.ps1 (logic-plus, ASCII-safe)
# Enhancements:
# - Strictly consider only today's events (local time)
# - Module bonuses (e.g., C06/C07/G43)
# - Exclude maintenance modules from TOP (archive, drills, auto-ops, c11_*)
# - Always form TOP-3 if there are items; sorts by (Score desc, TS desc)
# - Extra diagnostics in the MD output

param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$ErrorActionPreference = "SilentlyContinue"

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

# ---------------- Config ----------------
# Bonuses by module (case-insensitive contains match)
$moduleBonuses = @{
  "c06" = 2
  "c07" = 2
  "g43" = 1
}

# Exclude modules (exact or prefix)
$excludeModules = @(
  "c05-archive",
  "restore-drill",
  "auto-archive"
)
# exclude any module starting with c11_
$excludePrefix = "c11_"

# Status weights
$statusWeights = @{
  "PROGRESS" = 1
  "START"    = 1
  "OK"       = 0
}

# Base tag scores
function Get-TagScore($msg) {
  if ($msg -match "\[RED\]") { return 3 }
  elseif ($msg -match "\[YEL\]") { return 2 }
  else { return 1 }
}

# Module bonus (case-insensitive contains)
function Get-ModuleBonus($module) {
  $m = $module.ToLower()
  $bonus = 0
  foreach ($k in $moduleBonuses.Keys) {
    if ($m -like "*$k*") { $bonus += [int]$moduleBonuses[$k] }
  }
  return $bonus
}

# Exclusion
function Is-Excluded($module) {
  $m = $module.ToLower()
  if ($m -eq $null) { return $false }
  if ($m.StartsWith($excludePrefix)) { return $true }
  foreach ($x in $excludeModules) {
    if ($m -eq $x) { return $true }
  }
  return $false
}
# ----------------------------------------

# Read recent lines (wider window)
$lines = Get-Content $logPath | Select-Object -Last 5000

# Parse and keep only today's items
$re = "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)"
$today = (Get-Date).Date
$items = @()
foreach ($ln in $lines) {
  if ($ln -match $re) {
    $ts     = [datetime]$Matches.ts
    if ($ts.Date -ne $today) { continue }
    $module = $Matches.module.Trim()
    $status = $Matches.status.Trim().ToUpper()
    $msg    = $Matches.msg.Trim()

    if (Is-Excluded $module) { continue }

    $score = 0
    $score += Get-TagScore $msg
    if ($statusWeights.ContainsKey($status)) { $score += [int]$statusWeights[$status] }
    $score += Get-ModuleBonus $module

    $items += New-Object psobject -Property @{
      TS=$ts; Module=$module; Status=$status; Msg=$msg; Score=[int]$score
    }
  }
}

# Sort: TS desc, then Score desc (two-pass for legacy)
$sorted = @($items | Sort-Object TS -Descending | Sort-Object Score -Descending)

$top  = @($sorted | Select-Object -First $MaxTop)
$back = @($sorted | Select-Object -Skip $top.Count -First 10)

# Prepare output
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$diag = @()
$diag += ($sorted | Select-Object -First 5 | ForEach-Object { "- [" + $_.Module + "] score=" + $_.Score + " status=" + $_.Status + " ts=" + $_.TS.ToString('HH:mm:ss') })

$md = @()
$md += "# Focus (auto, test)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## Selection"
$md += "- Consider only today's events"
$md += "- Parsed window (lines): 5000"
$md += "- Candidates after filters: " + $items.Count
$md += "- Diagnostics (first 5):"
if ($diag.Count -gt 0) { $md += $diag } else { $md += "- none" }
$md += ""
$md += "## TOP-" + $MaxTop
if ($top.Count -gt 0) {
  $md += ($top | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (score=" + $_.Score + ", status=" + $_.Status + ", ts=" + $_.TS.ToString('HH:mm:ss') + ")"})
} else {
  $md += "- No items found."
}
$md += ""
$md += "## Backlog (up to 10)"
if ($back.Count -gt 0) {
  $md += ($back | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (score=" + $_.Score + ", status=" + $_.Status + ", ts=" + $_.TS.ToString('HH:mm:ss') + ")"})
} else {
  $md += "- Backlog is empty."
}
$md += ""
$md += "## Notes"
$md += "- Scoring: tag (RED=3, YEL=2, default=1) + status (PROGRESS/START=+1, OK=+0) + module bonus (C06=+2, C07=+2, G43=+1)"
$md += "- Excluded: c05-archive, restore-drill, auto-archive, any c11_*"
$md += "- Sorted by Score desc, then latest time"

$md | Set-Content -Path $outPath -Encoding UTF8

$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] focus logic-plus updated (candidates=" + $items.Count + ", top=" + $top.Count + ")"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "FOCUS_AUTO.md created (logic-plus) and log updated."
