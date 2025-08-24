# c11_focus_auto.ps1 (ASCII-safe, logical TOP-3)
# Rules:
# - Read up to last 5000 lines from C03/LOG.md
# - Prefer today's events (by date). If none, fallback to most recent events overall.
# - Priority score (higher is better):
#     RED tag -> +3
#     YEL tag -> +2
#     Default tag -> +1
#   Additional weighting by Status:
#     PROGRESS -> +1
#     START    -> +1
#     OK       -> +0
# - Sort by (Score desc, Timestamp desc)
# - Always return TOP-3 (or fewer if truly not enough events), with Backlog up to 10.
#
# Output: C06_dev\FOCUS_AUTO.md
# Log:    C03\LOG.md  (adds an [AUTO] line with counts and selection mode)

param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

# Read recent lines (increase window to 5000)
$lines = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 5000

# Parse log lines
$re = "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)"
$itemsAll = foreach($ln in $lines){
  if($ln -match $re) {
    $ts     = [datetime]$Matches.ts
    $module = $Matches.module.Trim()
    $status = $Matches.status.Trim().ToUpper()
    $msg    = $Matches.msg.Trim()

    # Base tag-based priority
    $tagScore = if ($msg -match "\[RED\]") { 3 } elseif ($msg -match "\[YEL\]") { 2 } else { 1 }

    # Status weighting
    $statusScore = if ($status -eq "PROGRESS" -or $status -eq "START") { 1 } else { 0 }

    $score = $tagScore + $statusScore

    [pscustomobject]@{
      TS=$ts; Module=$module; Status=$status; Msg=$msg;
      TagScore=$tagScore; StatusScore=$statusScore; Score=$score
    }
  }
}

if (-not $itemsAll) { $itemsAll = @() }

# Prefer today's events
$today = (Get-Date).Date
$todayItems = $itemsAll | Where-Object { $_.TS.Date -eq $today }

$selectionMode = if ($todayItems.Count -gt 0) { "today" } else { "fallback_recent" }
$srcItems = if ($selectionMode -eq "today") { $todayItems } else { $itemsAll }

# Sorting spec (Windows PowerShell compatible)
$sortSpec = @(
  @{ Expression = 'Score'; Descending = $true },
  @{ Expression = 'TS';    Descending = $true }
)

$top  = $srcItems | Sort-Object @sortSpec | Select-Object -First $MaxTop
$back = $srcItems | Where-Object { $_ -and ($top -notcontains $_) } | Sort-Object @sortSpec | Select-Object -First 10

# Prepare output folder
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

# Render markdown
$md = @()
$md += "# Focus (auto, test)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## Selection"
$md += "- Mode: " + $selectionMode
$md += "- Parsed events in window: " + $itemsAll.Count
$md += "- Considered events: " + $srcItems.Count
$md += ""
$md += "## TOP-" + $MaxTop
if ($top.Count -gt 0) {
  $md += ($top | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (score=" + $_.Score + ", tag=" + $_.TagScore + ", status=" + $_.Status + ", ts=" + $_.TS.ToString('HH:mm:ss') + ")"})
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
$md += "- Sorted by Score desc, then latest time"
$md += "- This is a dev-only file. Review before merging into C06/FOCUS.md."

$md | Set-Content -Path $outPath -Encoding UTF8

# Log entry
$topCount = if ($top) { $top.Count } else { 0 }
$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] FOCUS_AUTO.md updated (mode=" + $selectionMode + ", parsed=" + $itemsAll.Count + ", considered=" + $srcItems.Count + ", top=" + $topCount + ")"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "FOCUS_AUTO.md created in C06_dev (mode=" $selectionMode ") and log updated."
