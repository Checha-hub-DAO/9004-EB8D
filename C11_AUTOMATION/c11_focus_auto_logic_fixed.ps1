# c11_focus_auto.ps1 (ASCII-safe, logical TOP-3, legacy-friendly)
# Changes vs previous:
# - Use two-pass Sort-Object (TS desc, then Score desc) for compatibility with older Windows PowerShell
# - Force arrays with @() to avoid scalar pitfalls
# - Extra diagnostics in output and log when TOP is empty

param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$ErrorActionPreference = "SilentlyContinue"

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

# Read recent lines (increase window to 5000)
$lines = Get-Content $logPath | Select-Object -Last 5000

# Parse log lines
$re = "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)"
$itemsAll = @()
foreach ($ln in $lines) {
  if ($ln -match $re) {
    $ts     = [datetime]$Matches.ts
    $module = $Matches.module.Trim()
    $status = $Matches.status.Trim().ToUpper()
    $msg    = $Matches.msg.Trim()

    $tagScore = if ($msg -match "\[RED\]") { 3 } elseif ($msg -match "\[YEL\]") { 2 } else { 1 }
    $statusScore = if ($status -in @("PROGRESS","START")) { 1 } else { 0 }
    $score = [int]($tagScore + $statusScore)

    $itemsAll += New-Object psobject -Property @{
      TS=$ts; Module=$module; Status=$status; Msg=$msg;
      TagScore=$tagScore; StatusScore=$statusScore; Score=$score
    }
  }
}

if (-not $itemsAll) { $itemsAll = @() }

# Prefer today's events
$today = (Get-Date).Date
$todayItems = @($itemsAll | Where-Object { $_.TS.Date -eq $today })
$selectionMode = $(if ($todayItems.Count -gt 0) { "today" } else { "fallback_recent" })
$srcItems = @($(if ($selectionMode -eq "today") { $todayItems } else { $itemsAll }))

# Two-pass sort: first TS desc, then Score desc (stable sort behavior)
$sorted = @($srcItems | Sort-Object TS -Descending | Sort-Object Score -Descending)
$top  = @($sorted | Select-Object -First $MaxTop)
$back = @($sorted | Select-Object -Skip $top.Count -First 10)

# Prepare output folder
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

# Diagnostics (first 3 considered events)
$diag = @()
$diag += ($sorted | Select-Object -First 3 | ForEach-Object { "- [" + $_.Module + "] score=" + $_.Score + " status=" + $_.Status + " ts=" + $_.TS.ToString('HH:mm:ss') })

# Render markdown
$md = @()
$md += "# Focus (auto, test)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## Selection"
$md += "- Mode: " + $selectionMode
$md += "- Parsed events in window: " + $itemsAll.Count
$md += "- Considered events: " + $srcItems.Count
$md += "- First 3 considered (for debug):"
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
$md += "- Scoring: RED +3, YEL +2, default +1; PROGRESS/START +1"
$md += "- Sorted by Score desc, then latest time (two-pass sort for compatibility)"
$md += "- This is a dev-only file. Review before merging into C06/FOCUS.md."

$md | Set-Content -Path $outPath -Encoding UTF8

# Log entry
$topCount = if ($top) { $top.Count } else { 0 }
$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] FOCUS_AUTO.md updated (mode=" + $selectionMode + ", parsed=" + $itemsAll.Count + ", considered=" + $srcItems.Count + ", top=" + $topCount + ")"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "FOCUS_AUTO.md created in C06_dev (mode=" $selectionMode ") and log updated."
