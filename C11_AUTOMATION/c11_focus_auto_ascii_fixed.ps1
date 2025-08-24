# c11_focus_auto.ps1 (ASCII-safe, Windows PowerShell compatible)
param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

# Read last lines from log
$lines = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 500

# Parse log lines
$items = foreach($ln in $lines){
  if($ln -match "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)") {
    $prio = switch -regex ($Matches.msg) {
      "\[RED\]" {3; break}
      "\[YEL\]" {2; break}
      default   {1}
    }
    [pscustomobject]@{
      TS=[datetime]$Matches.ts
      Module=$Matches.module.Trim()
      Status=$Matches.status.Trim()
      Msg=$Matches.msg.Trim()
      Prio=$prio
    }
  }
}

# Ensure $items is not null
if (-not $items) { $items = @() }

# Sort by priority then time (descending)
$sortSpec = @(
  @{ Expression = 'Prio'; Descending = $true },
  @{ Expression = 'TS';   Descending = $true }
)
$top  = $items | Sort-Object @sortSpec | Select-Object -First $MaxTop
$back = $items | Where-Object { $_ -and ($top -notcontains $_) } | Sort-Object @sortSpec | Select-Object -First 10

# Prepare output folder
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

# Render markdown
$md = @()
$md += "# Focus (auto, test)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## TOP-$MaxTop"
if ($top.Count -gt 0) {
  $md += ($top | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg + " (prio=" + $_.Prio + ", status=" + $_.Status + ")"})
} else {
  $md += "- No items found in log"
}
$md += ""
$md += "## Backlog (10)"
if ($back.Count -gt 0) {
  $md += ($back | ForEach-Object {"- [" + $_.Module + "] " + $_.Msg})
} else {
  $md += "- Backlog is empty"
}
$md += ""
$md += "> Auto-generated. Review before merging into C06/FOCUS.md."

$md | Set-Content -Path $outPath -Encoding UTF8

# Log entry
$topCount = if ($top) { $top.Count } else { 0 }
$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] FOCUS_AUTO.md updated (top=" + $topCount + ")"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "FOCUS_AUTO.md created in C06_dev and log updated."
