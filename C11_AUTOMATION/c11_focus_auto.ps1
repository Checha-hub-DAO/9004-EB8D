# c11_focus_auto.ps1
param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$MaxTop = 3
)

$logPath   = Join-Path $Root "C03\LOG.md"
$outPath   = Join-Path $Root "C06_dev\FOCUS_AUTO.md"

$lines = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 500

$items = foreach($ln in $lines){
  if($ln -match "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)") {
    $prio = switch -regex ($Matches.msg) {
      "\[RED\]" {3; break}
      "\[YEL\]" {2; break}
      default   {1}
    }
    [pscustomobject]@{
      TS=$Matches.ts; Module=$Matches.module.Trim(); Status=$Matches.status.Trim()
      Msg=$Matches.msg.Trim(); Prio=$prio
    }
  }
}

$top   = $items | Sort-Object Prio -Descending, TS -Descending | Select-Object -First $MaxTop
$back  = $items | ? { $_ -notin $top } | Sort-Object Prio -Descending, TS -Descending | Select-Object -First 10

New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$md = @()
$md += "# FOCUS — авто (тест)  $((Get-Date).ToString('yyyy-MM-dd'))"
$md += ""
$md += "## 🎯 TOP-$MaxTop"
$md += ($top | ForEach-Object {"- **[$($_.Module)]** $($_.Msg) _(prio=$($_.Prio), status=$($_.Status))_"})
$md += ""
$md += "## 📥 Backlog (10)"
$md += ($back | ForEach-Object {"- [$($_.Module)] $($_.Msg)"})
$md += ""
$md += "> Згенеровано автоматично. Перевір і за потреби відредагуй перед merge до C06/FOCUS.md."

$md | Set-Content -Path $outPath -Encoding UTF8

$logEntry = "| $(Get-Date 'yyyy-MM-dd HH:mm:ss') | c11_focus_auto | OK | [AUTO] FOCUS_AUTO.md updated ($($top.Count) top)"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
