. "$PSScriptRoot\_env.ps1"
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
  [string]$AliasName = "c07",
  [string]$Bucket = "c07-reports",
  [string]$DockerNetwork = "checha_core_default"
)
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){ if(-not(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function ToInt($s){ $o=0; [void][int]::TryParse((($s+"") -replace "[^\d-]","").Trim(), [ref]$o); return $o }

# ISO week calc for Windows PowerShell 5.1 (Р В±Р ВµР В· System.Globalization.ISOWeek)
function Get-ISOWeekInfo([datetime]$date){
  $dow = ([int]$date.DayOfWeek + 6) % 7       # Mon=0..Sun=6
  $thu = $date.AddDays(3 - $dow)              # Thursday of current ISO week
  $isoYear = $thu.Year
  $jan4 = [datetime]::new($isoYear,1,4)
  $jan4dow = ([int]$jan4.DayOfWeek + 6) % 7
  $firstThu = $jan4.AddDays(3 - $jan4dow)
  $week = 1 + [int](([TimeSpan]($thu - $firstThu)).TotalDays / 7)
  $start = $thu.AddDays(-3).Date              # Monday
  $end = $start.AddDays(6)                    # Sunday
  return @{ Year=$isoYear; Week=$week; Start=$start; End=$end }
}

$kpiFile = Join-Path $Root "C07\KPI_TRACKER.md"
if(-not(Test-Path $kpiFile)){ throw "Р СњР Вµ Р В·Р Р…Р В°Р в„–Р Т‘Р ВµР Р…Р С• $kpiFile" }

$iso = Get-ISOWeekInfo (Get-Date)
$weekStr = "{0}-W{1:D2}" -f $iso.Year, $iso.Week
$weekStart = $iso.Start
$weekEnd   = $iso.End

# Р СџР В°РЎР‚РЎРѓР С‘Р СР С• РЎвЂљР В°Р В±Р В»Р С‘РЎвЂ РЎР‹ DAILY KPI
$txt = Get-Content -Raw -LiteralPath $kpiFile
$lines = $txt -split "`r?`n"

$sumOK=$sumFAIL=$sumPRO=$sumSTART=$sumBackups=$sumPub=$sumForms=$sumMeet=0
$lastBackup=""; $lastRestore=""
foreach($ln in $lines){
  if($ln -match '^\|\s*(\d{4}-\d{2}-\d{2})\s*\|'){
    $cols = ($ln -split '\|').ForEach({ $_.Trim() }) | Where-Object { $_ -ne "" }
    if($cols.Count -ge 11){
      $d = [datetime]$cols[0]
      if($d -ge $weekStart -and $d -le $weekEnd){
        $sumOK     += ToInt $cols[1]
        $sumFAIL   += ToInt $cols[2]
        $sumPRO    += ToInt $cols[3]
        $sumSTART  += ToInt $cols[4]
        $sumBackups+= ToInt $cols[5]
        if($cols[6] -and $cols[6] -ne ''){ $lastBackup  = $cols[6] }
        if($cols[7] -and $cols[7] -ne ''){ $lastRestore = $cols[7] }
        $sumPub    += ToInt $cols[8]
        $sumForms  += ToInt $cols[9]
        $sumMeet   += ToInt $cols[10]
      }
    }
  }
}

$events = $sumOK + $sumFAIL + $sumPRO + $sumSTART

$weeklyDir = Join-Path $Root "C07\reports\weekly"; Ensure-Dir $weeklyDir
$fname = "weekly_report_{0}.md" -f $weekStr
$out   = Join-Path $weeklyDir $fname

$fmtStart = $weekStart.ToString("yyyy-MM-dd")
$fmtEnd   = $weekEnd.ToString("yyyy-MM-dd")

$md = @"
# C07  Weekly Report ($weekStr)
Span: $fmtStart -> $fmtEnd

## KPI Summary
| Metric | Value |
|---|---:|
| Events (OK+FAIL+PROGRESS+START) | $events |
| OK | $sumOK |
| FAIL | $sumFAIL |
| PROGRESS | $sumPRO |
| START | $sumSTART |
| Backups (sum) | $sumBackups |
| LastBackup | $lastBackup |
| LastRestoreDrill | $lastRestore |
| Publications | $sumPub |
| FormsResponses | $sumForms |
| Meetings | $sumMeet |

## Notes
- _Р вЂќР С•Р Т‘Р В°Р в„– Р С”Р В»РЎР‹РЎвЂЎР С•Р Р†РЎвЂ“ Р С—Р С•Р Т‘РЎвЂ“РЎвЂ” РЎвЂљР С‘Р В¶Р Р…РЎРЏ РЎвЂљРЎС“РЎвЂљ._

## Risks / Issues
- _Р С›Р С—Р С‘РЎв‚¬Р С‘ Р С—РЎР‚Р С•Р В±Р В»Р ВµР СР С‘/РЎР‚Р С‘Р В·Р С‘Р С”Р С‘._

## Next Week Plan
- _Р СџР В»Р В°Р Р… РЎР‚Р С•Р В±РЎвЂ“РЎвЂљ._
"@

# Р вЂ”Р В°Р С—Р С‘РЎРѓ РЎС“ UTF-8 (no BOM)
[System.IO.File]::WriteAllText($out, $md, (New-Object System.Text.UTF8Encoding($false)))

# Р СџРЎС“Р В±Р В»РЎвЂ“Р С”РЎС“РЎвЂќР СР С• 1 РЎвЂћР В°Р в„–Р В» РЎС“ Р В±Р В°Р С”Р ВµРЎвЂљ
$cfgDir = Join-Path $Root ".mc"; Ensure-Dir $cfgDir
$vol = "$($weeklyDir):/data"
& docker run --rm --network $DockerNetwork -v "$($cfgDir):/root/.mc" -v $vol minio/mc cp --attr "Content-Type=text/markdown; charset=utf-8" "/data/$fname" "$AliasName/$Bucket/weekly/$fname"
if($LASTEXITCODE -ne 0){ throw "Р СњР Вµ Р Р†Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р С•Р С—РЎС“Р В±Р В»РЎвЂ“Р С”РЎС“Р Р†Р В°РЎвЂљР С‘ $fname" }

Write-Host "Generated: $out" -ForegroundColor Green
Write-Host "Published: $AliasName/$Bucket/weekly/$fname" -ForegroundColor Green




# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
