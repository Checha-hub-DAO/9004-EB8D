# --- logging (auto) ---
try{
  $\__logDir = Join-Path 'C:\CHECHA_CORE' '_logs'
  New-Item -ItemType Directory -Force -Path $\__logDir | Out-Null
  $\__log = Join-Path $\__logDir ("{0}_{1:yyyy-MM-dd_HHmmss}.log" -f $MyInvocation.MyCommand.Name, (Get-Date))
  Start-Transcript -Path $\__log -Force | Out-Null
} catch { }
. "\_env.ps1"
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$KpiFile = "",
  [datetime]$AsOf = (Get-Date),
  [switch]$Publish,
  [string]$AliasName = "c07",
  [string]$Bucket = "c07-reports",
  [string]$DockerNetwork = "checha_core_default",
  [switch]$Insecure
)

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Fail($m){ Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

if (-not $KpiFile -or $KpiFile -eq "") { $KpiFile = Join-Path $Root "C07\KPI_TRACKER.md" }
if (-not (Test-Path $KpiFile)) { Fail ("KPI file not found: {0}" -f $KpiFile) }

function Ensure-Path([string]$p){
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# Week helpers (Monday-based)
function Get-WeekStart([datetime]$d) {
  $dow = [int]$d.DayOfWeek
  $offset = ($dow - 1)
  if ($offset -lt 0) { $offset = 6 }
  return $d.Date.AddDays(-$offset)
}
function Get-WeekLabel([datetime]$d) {
  $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
  $weekNum = $cal.GetWeekOfYear($d, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
  return ("{0}-W{1:D2}" -f $d.Year, $weekNum)
}

$weekStart = Get-WeekStart $AsOf
$weekEnd   = $weekStart.AddDays(6)
$weekLabel = Get-WeekLabel $AsOf
$spanText  = ("{0:yyyy-MM-dd} -> {1:yyyy-MM-dd}" -f $weekStart, $weekEnd)
Info ("Weekly span: {0}" -f $spanText)

# Read KPI
$content = Get-Content $KpiFile -Raw

# Parse DAILY KPI rows
$rows = @()
$regex = [regex]::new('(?m)^\|\s*(?<date>\d{4}[-\p{Pd}]\d{2}[-\p{Pd}]\d{2})\s*\|(?<rest>.*)$')
$matches = $regex.Matches($content)
foreach ($m in $matches) {
  $dateStr = $m.Groups["date"].Value -replace '[\p{Pd}]','-'
  try { $d = [datetime]::ParseExact($dateStr, "yyyy-MM-dd", $null) } catch { continue }
  if ($d -lt $weekStart -or $d -gt $weekEnd) { continue }

  $line = $m.Value
  $cols = ($line -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  if ($cols.Count -lt 13) { continue }

  $row = [ordered]@{
    Date = $d
    OK   = 0; FAIL = 0; PROGRESS = 0; START = 0
    Backups = 0
    LastBackup = ""
    LastRestoreDrill = ""
    Publications = 0; FormsResponses = 0; Meetings = 0
    Notes = $cols[11]
    Source = $cols[12]
  }
  [int]::TryParse($cols[1], [ref]$row.OK)            | Out-Null
  [int]::TryParse($cols[2], [ref]$row.FAIL)          | Out-Null
  [int]::TryParse($cols[3], [ref]$row.PROGRESS)      | Out-Null
  [int]::TryParse($cols[4], [ref]$row.START)         | Out-Null
  [int]::TryParse($cols[5], [ref]$row.Backups)       | Out-Null
  $lb = $cols[6]; if ($lb -and $lb -ne "вЂ”" -and $lb -ne "-") { $row.LastBackup = $lb }
  $rd = $cols[7]; if ($rd -and $rd -ne "вЂ”" -and $rd -ne "-") { $row.LastRestoreDrill = $rd }
  [int]::TryParse($cols[8], [ref]$row.Publications)  | Out-Null
  [int]::TryParse($cols[9], [ref]$row.FormsResponses)| Out-Null
  [int]::TryParse($cols[10], [ref]$row.Meetings)     | Out-Null
  $rows += ,$row
}

if ($rows.Count -eq 0) {
  Warn "No DAILY KPI rows found for this week span."
}

# Aggregate
$sumOK = ($rows | Measure-Object -Property OK -Sum).Sum
$sumFAIL = ($rows | Measure-Object -Property FAIL -Sum).Sum
$sumPROGRESS = ($rows | Measure-Object -Property PROGRESS -Sum).Sum
$sumSTART = ($rows | Measure-Object -Property START -Sum).Sum
$sumBackups = ($rows | Measure-Object -Property Backups -Sum).Sum
$events = ($sumOK + $sumFAIL + $sumPROGRESS + $sumSTART)
$lastBackup = ($rows | Where-Object { $_.LastBackup } | Sort-Object Date -Descending | Select-Object -First 1).LastBackup
if (-not $lastBackup) { $lastBackup = "вЂ”" }
$lastRestore = ($rows | Where-Object { $_.LastRestoreDrill } | Sort-Object Date -Descending | Select-Object -First 1).LastRestoreDrill
if (-not $lastRestore) { $lastRestore = "вЂ”" }

# Upsert WEEKLY KPI row
$weeklyRow = ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |" -f $weekLabel, $spanText, $events, $sumOK, $sumFAIL, $sumPROGRESS, $sumSTART, $sumBackups, $lastBackup, $lastRestore)

$weeklyHeaderRegex = [regex]::new('(?ms)(###\s*2\)\s*WEEKLY\s*KPI.*?\n)(\|.*?\n)(\|[-:\s|]+\n)')
$m = $weeklyHeaderRegex.Match($content)
if (-not $m.Success) { Fail "Could not locate WEEKLY KPI table header in KPI file." }
$existingRegex = [regex]::new("(?m)^\|\s*{0}\s*\|.*$" -f [regex]::Escape($weekLabel))
if ($existingRegex.IsMatch($content)) {
  $content = $existingRegex.Replace($content, $weeklyRow, 1)
  Info ("Updated WEEKLY KPI row for {0}" -f $weekLabel)
} else {
  $insertPos = $m.Groups[1].Index + $m.Groups[1].Length + $m.Groups[2].Length + $m.Groups[3].Length
  $content = $content.Substring(0, $insertPos) + $weeklyRow + "`r`n" + $content.Substring($insertPos)
  Info ("Inserted WEEKLY KPI row for {0}" -f $weekLabel)
}
Set-Content -Path $KpiFile -Value $content -Encoding UTF8
Ok ("WEEKLY KPI updated: {0}" -f $weekLabel)

# Generate weekly report markdown
$reportDir = Join-Path $Root "C07\reports\weekly"
Ensure-Path $reportDir
$reportFile = Join-Path $reportDir ("weekly_report_{0}.md" -f $weekLabel)

$report = @()
$report += "# Weekly Report - {0}" -f ("{0:yyyy-MM-dd}" -f $weekEnd)
$report += ""
$report += "## 1) Summary"
$report += ("- Span: {0}" -f $spanText)
$report += ("- Totals: Events={0}; OK={1}; FAIL={2}; PROGRESS={3}; START={4}" -f $events,$sumOK,$sumFAIL,$sumPROGRESS,$sumSTART)
$report += ("- Reliability: Backups={0}; LastBackup={1}; LastRestoreDrill={2}" -f $sumBackups,$lastBackup,$lastRestore)
$report += ""
$report += "## 2) Key Events (3-7)"
$report += "- [ ] Event 1 (Source: <link or ID>)"
$report += "- [ ] Event 2"
$report += "- [ ] Event 3"
$report += ""
$report += "## 3) Risks / Blockers"
$report += "- R1:"
$report += "- R2:"
$report += ""
$report += "## 4) Actions (with deadlines)"
$report += "- D1: what/who/when"
$report += "- D2: ..."
$report += ""
$report += "## 5) Publications"
$report += "- list links/files"
$report += ""
$report += "## 6) Intake / Feedback"
$report += "- forms/responses summary"
$report += ""
$report += "## 7) Notes"
$report += "- observations/context"
$report += ""

Set-Content -Path $reportFile -Value ($report -join "`r`n") -Encoding UTF8
Ok ("Weekly report generated: {0}" -f $reportFile)

# Optional publish
if ($Publish) {
  $pubScript = Join-Path $Root "tools\publish_c07_v4.ps1"
  if (Test-Path $pubScript) {
    & $pubScript -Root $Root -AliasName $AliasName -Bucket $Bucket -DockerNetwork $DockerNetwork -Insecure:$Insecure
    if ($LASTEXITCODE -ne 0) { Fail "Publish script failed." }
  } else {
    Warn "publish_c07_v4.ps1 not found, attempting inline docker mc publish..."
    $cfgDir = Join-Path $Root ".mc"
    if (-not (Test-Path $cfgDir)) { Fail "Missing .mc config dir for mc alias." }
    $c07 = Join-Path $Root "C07"
    $mcGlobal = @()
    if ($Insecure) { $mcGlobal += "--insecure" }
    docker run --rm --network $DockerNetwork -v "$cfgDir:/root/.mc" minio/mc @($mcGlobal + @("mb","--ignore-existing","{0}/{1}" -f $AliasName,$Bucket)) | Out-Null
    docker run --rm --network $DockerNetwork -v "$cfgDir:/root/.mc" -v "$c07:/data" minio/mc @($mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} {0}/{1}/" -f $AliasName,$Bucket))
    if ($LASTEXITCODE -ne 0) { Fail "Inline publish failed." }
  }
  Ok "Published updated C07 (including weekly report) to bucket."
}
# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
