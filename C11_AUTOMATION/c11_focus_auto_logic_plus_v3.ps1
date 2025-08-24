# c11_focus_auto.ps1 (logic-plus v3, ASCII-safe)
# Features:
# - Consider only today's events
# - Score = TagScore (explicit tags or keywords) + StatusWeight + ModuleBonus
# - Module bonuses: C06=+3, C07=+2, G43=+1  (case-insensitive contains)
# - Exclude maintenance: c05-archive, restore-drill, auto-archive, any c11_*
# - TOP selection: per-module cap = 2 AND guarantee >=1 item from core (C06/C07)
# - Backlog: diversity cap = 3 per module in first 10 entries
# - Sort: Score desc, then time desc (two-pass for legacy PowerShell)
# - Diagnostics included in output

param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$ErrorActionPreference = "SilentlyContinue"

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

# ---------------- Config ----------------
# Module bonuses (contains match, case-insensitive)
$moduleBonuses = @{
  "c06" = 3
  "c07" = 2
  "g43" = 1
}

# Exclusions
$excludeModules = @("c05-archive","restore-drill","auto-archive")
$excludePrefix  = "c11_"

# Status weights
$statusWeights = @{
  "PROGRESS" = 2
  "START"    = 1
  "OK"       = 0
}

# Keyword dictionaries (case-insensitive)
$redKeywords  = @("deadline","blocked","risk","incident","urgent","critical","sev","breach","failure","outage","overdue","sla","delay risk")
$yelKeywords  = @("dependency","review needed","pending approval","waiting","hold","defer","follow up","remind","needs review")

function Get-TagScore($msg) {
  # Explicit tags have priority
  if ($msg -match "\[RED\]") { return 3 }
  if ($msg -match "\[YEL\]") { return 2 }
  # Keyword-based tags (case-insensitive)
  $m = $msg.ToLower()
  foreach ($w in $redKeywords) { if ($m -like "*$w*") { return 3 } }
  foreach ($w in $yelKeywords) { if ($m -like "*$w*") { return 2 } }
  return 1
}

function Get-ModuleBonus($module) {
  $m = $module.ToLower()
  $bonus = 0
  foreach ($k in $moduleBonuses.Keys) {
    if ($m -like "*$k*") { $bonus += [int]$moduleBonuses[$k] }
  }
  return $bonus
}

function Is-Excluded($module) {
  $m = $module.ToLower()
  if ($m.StartsWith($excludePrefix)) { return $true }
  foreach ($x in $excludeModules) { if ($m -eq $x) { return $true } }
  return $false
}

function Is-CoreModule($module) {
  $m = $module.ToLower()
  return ($m -like "*c06*" -or $m -like "*c07*")
}
# ----------------------------------------

# Read recent lines
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

# Sort all candidates: TS desc, then Score desc
$sorted = @($items | Sort-Object TS -Descending | Sort-Object Score -Descending)

# Build TOP with per-module cap = 2
$top = @()
$counts = @{}
foreach ($it in $sorted) {
  if ($top.Count -ge $MaxTop) { break }
  $key = $it.Module.ToLower()
  if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
  if ($counts[$key] -ge 2) { continue }
  $top += $it
  $counts[$key] = $counts[$key] + 1
}

# Guarantee at least 1 item from core (C06/C07)
$hasCore = $false
foreach ($t in $top) { if (Is-CoreModule $t.Module) { $hasCore = $true; break } }

if (-not $hasCore) {
  # Find best core candidate not in TOP
  $coreCandidate = $null
  foreach ($it in $sorted) {
    $already = $false
    foreach ($t in $top) { if ($t -eq $it) { $already = $true; break } }
    if ($already) { continue }
    if (Is-CoreModule $it.Module) {
      # Also respect per-module cap (but since there is no core in TOP, this is safe)
      $coreCandidate = $it
      break
    }
  }
  if ($coreCandidate -ne $null) {
    # Replace the last item in TOP (lowest priority by our sort: it's the last)
    if ($top.Count -gt 0) {
      $top[$top.Count - 1] = $coreCandidate
    } else {
      $top += $coreCandidate
    }
  }
}

# Build Backlog up to 10 with diversity cap = 3 per module
$back = @()
$bkCounts = @{}
foreach ($it in $sorted) {
  if ($back.Count -ge 10) { break }
  # skip those already in TOP
  $skip = $false
  foreach ($t in $top) { if ($t -eq $it) { $skip = $true; break } }
  if ($skip) { continue }
  $key = $it.Module.ToLower()
  if (-not $bkCounts.ContainsKey($key)) { $bkCounts[$key] = 0 }
  if ($bkCounts[$key] -ge 3) { continue }
  $back += $it
  $bkCounts[$key] = $bkCounts[$key] + 1
}

# Prepare output
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

# Diagnostics (first 5 sorted)
$diag = @()
$diag += ($sorted | Select-Object -First 5 | ForEach-Object { "- [" + $_.Module + "] score=" + $_.Score + " status=" + $_.Status + " ts=" + $_.TS.ToString('HH:mm:ss') })

$md = @()
$md += "# Focus (auto, test)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## Selection"
$md += "- Consider only today's events"
$md += "- Candidates after filters: " + $items.Count
$md += "- Diagnostics (first 5 sorted):"
if ($diag.Count -gt 0) { $md += $diag } else { $md += "- none" }
$md += ""
$md += "## TOP-" + $MaxTop + " (cap 2 per module, guarantee >=1 from C06/C07)"
if ($top.Count -gt 0) {
  $md += ($top | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (score=" + $_.Score + ", status=" + $_.Status + ", ts=" + $_.TS.ToString('HH:mm:ss') + ")"})
} else {
  $md += "- No items found."
}
$md += ""
$md += "## Backlog (up to 10, max 3 per module)"
if ($back.Count -gt 0) {
  $md += ($back | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (score=" + $_.Score + ", status=" + $_.Status + ", ts=" + $_.TS.ToString('HH:mm:ss') + ")"})
} else {
  $md += "- Backlog is empty."
}
$md += ""
$md += "## Notes"
$md += "- Score = Tag (explicit [RED]/[YEL] or keywords) + Status + ModuleBonus"
$md += "- Status weights: PROGRESS=+2, START=+1, OK=0"
$md += "- Module bonuses: C06=+3, C07=+2, G43=+1"
$md += "- Excluded: c05-archive, restore-drill, auto-archive, any c11_*"
$md += "- Sorted by Score desc, then latest time"
$md += "- Guarantee: at least one item from C06/C07 is included in TOP, replacing the last item if needed"

$md | Set-Content -Path $outPath -Encoding UTF8

# Log entry
$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] focus logic-plus v3 (candidates=" + $items.Count + ", top=" + $top.Count + ")"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "FOCUS_AUTO.md created (logic-plus v3) and log updated."
