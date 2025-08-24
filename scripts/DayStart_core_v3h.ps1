# DayStart_core_v3h.ps1 — hardened Day Start for CHECHA_CORE
# - Auto checkpoint if no backups today
# - Robust backup counting (@($bk).Count)
# - Dedup "Update" blocks within today's section (keep only latest)
# - Dedup header "### Day Start — YYYY-MM-DD" for today (keep only one)
# Encoding: UTF-8 (with BOM)

$ErrorActionPreference = 'Stop'

$root  = 'C:\CHECHA_CORE'
$log   = Join-Path $root 'C03\LOG.md'
$rep   = Join-Path $root 'C07\REPORT.md'
$hs    = Join-Path $root 'C07\health-summary.md'
$kpi   = Join-Path $root 'C07\KPI_TRACKER.md'
$topic = Join-Path $root 'G43\topics\ITETA_Topic_003.md'

$today = Get-Date -Format 'yyyy-MM-dd'
$nowTS = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$nowHM = Get-Date -Format 'HH:mm'

# Ensure folders exist
New-Item (Join-Path $root 'C03') -ItemType Directory -Force | Out-Null
New-Item (Join-Path $root 'C07') -ItemType Directory -Force | Out-Null
New-Item (Join-Path $root 'G43\topics') -ItemType Directory -Force | Out-Null

# 0) REPORT — Day Start header (idempotent)
$hdr = "### Day Start — $today"
$hdrEsc = [regex]::Escape($hdr)
$repHasHdr = if (Test-Path $rep) { Select-String -Path $rep -Pattern $hdrEsc -Quiet } else { $false }
if(-not $repHasHdr){
@"
$hdr
- Plan: WIP 1 core + 1 creative; >=1 event in LOG; >=1 backup.
- Kickoff: G43 Topic #3 v0.1 (draft) — skeleton + TL;DR/Signals/Impact.
- By end of day: sync `health-summary` and `KPI`.
"@ | Add-Content -Path $rep -Encoding UTF8
}

# 0.1) Dedup today's "Day Start" header (keep first, drop the rest)
if (Test-Path $rep) {
  $txt = Get-Content $rep -Raw -Encoding UTF8
  $rxHdrToday = "(?m)^### Day Start [—-] $([regex]::Escape($today))\s*$"
  $m = [regex]::Matches($txt, $rxHdrToday)
  if ($m.Count -gt 1) {
    # Keep the first occurrence only
    $firstIdx = $m[0].Index
    # Replace subsequent occurrences with empty string
    for ($i=1; $i -lt $m.Count; $i++) {
      $match = $m[$i]
      $txt = $txt.Remove($match.Index, $match.Length)
      # After removal, future indices shift; recompute matches relative to new text
      $m = [regex]::Matches($txt, $rxHdrToday)
    }
    Set-Content -Path $rep -Value $txt -Encoding UTF8
  }
}

# 1) LOG — day start (idempotent)
$rxDayStart="^\s*\|\s*$([regex]::Escape($today))\s+\d{2}:\d{2}:\d{2}\s*\|\s*c07-report\s*\|\s*OK\s*\|\s*day start\s*$"
$hasDayStart = if (Test-Path $log) { Select-String -Path $log -Pattern $rxDayStart -Quiet } else { $false }
if(-not $hasDayStart){
  Add-Content $log ("| {0} | c07-report | OK | day start" -f $nowTS)
}

# 2) Topic #3 — create skeleton (if missing) + LOG START (idempotent)
if(-not (Test-Path $topic)){
@"
# ITETA Topic #3
Status: v0.1 (draft)

## TL;DR
(1–2 sentences)

## Signals
- [ ] Signal 1
- [ ] Signal 2
- [ ] Signal 3

## Impact
- Thesis 1
- Thesis 2
- Thesis 3

## Acceptance / Done
- [ ] TL;DR
- [ ] >=3 signals
- [ ] 2–3 impact theses
- [ ] Logged in LOG + REPORT

Changelog:
- $today $nowHM — v0.1: skeleton created.
"@ | Set-Content $topic -Encoding UTF8
}

$rxT3="^\s*\|\s*$([regex]::Escape($today))\s+\d{2}:\d{2}:\d{2}\s*\|\s*g43-iteta\s*\|\s*START\s*\|\s*topic #3"
$hasT3 = if (Test-Path $log) { Select-String -Path $log -Pattern $rxT3 -Quiet } else { $false }
if(-not $hasT3){
  Add-Content $log ("| {0} | g43-iteta | START | topic #3 created (ITETA_Topic_003.md)" -f $nowTS)
}

# 3) Parse today's events
$rx='^\s*\|\s*(?<d>\d{4}-\d{2}-\d{2})\s+(?<t>\d{2}:\d{2}:\d{2})\s*\|\s*(?<m>[^|]+?)\s*\|\s*(?<s>[^|]+?)\s*\|(?<msg>.*)$'
$ev=@()
if(Test-Path $log){
  Get-Content $log | ForEach-Object {
    if($_ -match $rx -and $Matches['d'] -eq $today){
      $ev += [pscustomobject]@{
        DT = Get-Date("$($Matches['d']) $($Matches['t'])")
        T  = $Matches['t']
        M  = $Matches['m'].Trim()
        S  = $Matches['s'].Trim().ToUpper()
        Line = $_
      }
    }
  }
}
function Cnt($n){ ($ev | Where-Object { $_.S -eq $n } | Measure-Object).Count }
$tot=$ev.Count; $ok=Cnt 'OK'; $fail=Cnt 'FAIL'; $prog=Cnt 'PROGRESS'; $start=Cnt 'START'
$byStat = if($ev){ ($ev | Group-Object S | ForEach-Object { '{0}={1}' -f $_.Name,$_.Count }) -join ', ' } else { '—' }
$byMod  = if($ev){ ($ev | Group-Object M | ForEach-Object { '{0}={1}' -f $_.Name,$_.Count }) -join ', ' } else { '—' }

# Backups(today) + LastBackup(time)
$bk = $ev | Where-Object { $_.M -eq 'c05-archive' -and $_.S -eq 'OK' }
$bkCount = @($bk).Count
$bkTime  = if($bkCount -gt 0){ ($bk | Sort-Object DT | Select-Object -Last 1).T } else { '—' }

# 3.1) Auto checkpoint if no backups today
if ($bkCount -eq 0) {
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -LiteralPath $log ("| {0} | c05-archive | OK | auto checkpoint" -f $ts)

  # Update in-memory collections
  $ev += [pscustomobject]@{
    DT = Get-Date($ts)
    T  = $ts.Split()[1]
    M  = 'c05-archive'
    S  = 'OK'
    Line = "| $ts | c05-archive | OK | auto checkpoint"
  }
  $bkCount = 1
  $bkTime  = $ts.Split()[1]

  # Recompute totals
  function Cnt($n){ ($ev | Where-Object { $_.S -eq $n } | Measure-Object).Count }
  $tot=$ev.Count; $ok=Cnt 'OK'; $fail=Cnt 'FAIL'; $prog=Cnt 'PROGRESS'; $start=Cnt 'START'
  $byStat = ($ev | Group-Object S | ForEach-Object { '{0}={1}' -f $_.Name,$_.Count }) -join ', '
  $byMod  = ($ev | Group-Object M | ForEach-Object { '{0}={1}' -f $_.Name,$_.Count }) -join ', '
}

# 4) KPI — table and upsert today's row
if(-not (Test-Path $kpi)){
@"
# KPI Tracker

| Date | Events | OK | FAIL | PROGRESS | START | Backups(today) | LastBackup(time) | LastRestoreDrill |
|---|---:|---:|---:|---:|---:|---:|---|---|
"@ | Set-Content $kpi -Encoding UTF8
}
$lines = Get-Content $kpi | Where-Object { $_ -notmatch "^\|\s*$([regex]::Escape($today))\s*\|" }
$row   = "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $today,$tot,$ok,$fail,$prog,$start,$bkCount,$bkTime,'—'
$lines + $row | Set-Content $kpi -Encoding UTF8

# 5) REPORT — Update marker (idempotent)
$marker = "### Update $nowHM — Day Start executed"
$markerEsc = [regex]::Escape($marker)
$repHasMarker = if (Test-Path $rep) { Select-String -Path $rep -Pattern $markerEsc -Quiet } else { $false }
if(-not $repHasMarker){
@"
$marker
- Today: total=$tot; status=[$byStat]; modules=[$byMod]. (KPI updated)
"@ | Add-Content -Path $rep -Encoding UTF8
}

# 5.1) Dedup "Update" blocks within today's section only
if (Test-Path $rep) {
  $txt = Get-Content $rep -Raw -Encoding UTF8

  # today's section range
  $mStart = [regex]::Match($txt, "(?m)^" + [regex]::Escape($hdr) + "\s*$")
  if ($mStart.Success) {
    $start = $mStart.Index
    $after = $txt.Substring($start + $mStart.Length)
    $mNext = [regex]::Match($after, "(?m)^### Day Start [—-] \d{4}-\d{2}-\d{2}\s*$")
    $end   = if ($mNext.Success) { $start + $mStart.Length + $mNext.Index } else { $txt.Length }

    $section = $txt.Substring($start, $end - $start)

    # 2-line Update blocks (— or -)
    $rxUpd = '(?m)^### Update \d{2}:\d{2} [—-] Day Start executed\r?\n- Today:.*\r?\n'
    $mm = [regex]::Matches($section, $rxUpd)
    if ($mm.Count -gt 1) {
      $last = $mm[$mm.Count-1].Value
      $section = [regex]::Replace($section, $rxUpd, '')
      $section = ($section.TrimEnd() + "`r`n" + $last)
      $txt = $txt.Substring(0,$start) + $section + $txt.Substring($end)
      Set-Content $rep -Value $txt -Encoding UTF8
    }
  }
}

# 6) Last restore-drill (latest in LOG)
$rd = if (Test-Path $log) {
  Select-String -Path $log -Pattern '^\s*\|\s*(?<dd>\d{4}-\d{2}-\d{2})\s+(?<tt>\d{2}:\d{2}:\d{2})\s*\|\s*restore-drill\s*\|\s*(?<st>[^|]+?)\s*\|' -AllMatches | Select-Object -Last 1
} else { $null }
$rdCell = if($rd){ '{0} {1} {2}' -f $rd.Matches[0].Groups['dd'].Value,$rd.Matches[0].Groups['tt'].Value,$rd.Matches[0].Groups['st'].Value.Trim().ToUpper() } else { '—' }

# 7) health-summary — rebuild
$g1 = $ev | Group-Object M,S | ForEach-Object { [pscustomobject]@{ Module=$_.Group[0].M; Status=$_.Group[0].S; Count=$_.Count } } | Sort-Object Module,Status
$g2 = $ev | Group-Object M   | ForEach-Object { [pscustomobject]@{ Module=$_.Name;    Count=$_.Count } } | Sort-Object Module

$md=@("# health-summary — Date $today","","## Events")
if($ev){ $md+='```'; $md+=$ev.Line; $md+='```' } else { $md+="_No events for today._" }
$md+="","## Counters (Module × Status)","","| Module | Status | Count |","|---|---|---|"
if($g1){ foreach($r in $g1){ $md+="| $($r.Module) | $($r.Status) | $($r.Count) |" } } else { $md+="| — | — | 0 |" }
$md+="","## Modules (total today)","","| Module | Count |","|---|---:|"
if($g2){ foreach($r in $g2){ $md+="| $($r.Module) | $($r.Count) |" } } else { $md+="| — | 0 |" }
Set-Content $hs -Value ($md -join "`r`n") -Encoding UTF8

# 8) Tail
"OK: day start done -> total=$tot; OK=$ok; PROGRESS=$prog; START=$start; FAIL=$fail; backups=$bkCount last=$bkTime; restore=$rdCell"
Get-Content $kpi -Tail 3
Get-Content $rep -Tail 12
Get-Content $hs  -Tail 14
