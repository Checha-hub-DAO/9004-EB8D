# WeeklySummary.ps1 (v2.4)  PS 5.1, ASCII-safe, idempotent, Span days fixed
$ErrorActionPreference='Stop'
try{ [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() }catch{}

$root='C:\CHECHA_CORE'
$kpi = Join-Path $root 'C07\KPI_TRACKER.md'
$wk  = Join-Path $root 'C07\WEEKLY.md'
$log = Join-Path $root 'C03\LOG.md'

New-Item (Join-Path $root 'C07') -ItemType Directory -Force | Out-Null
if(-not (Test-Path $wk)){ Set-Content -Path $wk -Value "# WEEKLY" -Encoding UTF8 }
if(-not (Test-Path $log)){ New-Item -ItemType File -Path $log | Out-Null }
if(-not (Test-Path $kpi)){ return }

# ---- parse KPI data rows
$lines = Get-Content -LiteralPath $kpi -ErrorAction Stop
$rows = foreach($l in $lines){
  if($l -match '^\s*\|\s*\d{4}-\d{2}-\d{2}\s*\|'){
    $p = $l -split '\|'
    [pscustomobject]@{
      Date=[datetime]::ParseExact($p[1].Trim(),'yyyy-MM-dd',$null)
      Events=[int]$p[2]; OK=[int]$p[3]; FAIL=[int]$p[4]; PROGRESS=[int]$p[5]; START=[int]$p[6]
      Backups=[int]$p[7]; LastBackup=$p[8].Trim(); LastRestoreDrill=$p[9].Trim(); Raw=$l.Trim()
    }
  }
}

$today=(Get-Date).Date
$from=$today.AddDays(-6)                  # останні 7 календарних днів
$spanDays=((New-TimeSpan -Start $from -End $today).Days + 1)

$week=$rows | Where-Object{ $_.Date -ge $from -and $_.Date -le $today } | Sort-Object Date
if(-not $week){ return }

# ---- aggregates
$sum=[pscustomobject]@{
  Events=($week|measure Events -Sum).Sum
  OK=($week|measure OK -Sum).Sum
  FAIL=($week|measure FAIL -Sum).Sum
  PROG=($week|measure PROGRESS -Sum).Sum
  START=($week|measure START -Sum).Sum
  BK=($week|measure Backups -Sum).Sum
  Days=$week.Count
}
$best=$week | Sort-Object OK -Desc | Select-Object -First 1
$lastRD=($week | Where-Object{ $_.LastRestoreDrill -and $_.LastRestoreDrill -notin @('N/A','','-','') } | Select-Object -Last 1)
$lastRDText=if($lastRD){ $lastRD.LastRestoreDrill } else { 'N/A' }

# ---- build block
$hdrLine="## Weekly Summary - " + $today.ToString('yyyy-MM-dd')
$md=@()
$md+=""; $md+=$hdrLine
$md+=("- Span: {0} - {1} ({2} days)" -f $from.ToString('yyyy-MM-dd'), $today.ToString('yyyy-MM-dd'), $spanDays)
$md+=("- Totals: Events={0}; OK={1}; FAIL={2}; PROGRESS={3}; START={4}; Backups={5}" -f $sum.Events,$sum.OK,$sum.FAIL,$sum.PROG,$sum.START,$sum.BK)
$md+=("- Best day (OK): {0} ({1} OK)" -f $best.Date.ToString('yyyy-MM-dd'), $best.OK)
$md+=("- Last restore drill: {0}" -f $lastRDText)
$md+=""
$md+="| Date | Events | OK | FAIL | PROGRESS | START | Backups(today) | LastBackup(time) | LastRestoreDrill |"
$md+="|---|---:|---:|---:|---:|---:|---:|---|---|"
$md+=($week | ForEach-Object{ $_.Raw })

# ---- idempotent write (safe for empty file)
$existing = if(Test-Path $wk){ Get-Content -LiteralPath $wk -Raw -Encoding UTF8 } else { "# WEEKLY`r`n" }
if ([string]::IsNullOrEmpty($existing)) { $existing = "# WEEKLY`r`n" }

$escHdr=[regex]::Escape($hdrLine)
$rx="(?ms)^$escHdr\s*.*?(?=^## Weekly Summary - |\z)"
try { $existing2=[regex]::Replace($existing,$rx,'') } catch { $existing2=$existing }

$final=($existing2.TrimEnd() + "`r`n`r`n" + ($md -join "`r`n"))
Set-Content -LiteralPath $wk -Value $final -Encoding UTF8

Add-Content -LiteralPath $log ("| {0} | weekly-summary | OK | span {1}..{2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$from.ToString('yyyy-MM-dd'),$today.ToString('yyyy-MM-dd'))
