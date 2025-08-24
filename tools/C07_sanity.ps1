# --- logging (auto) ---
try{
  $\__logDir = Join-Path 'C:\CHECHA_CORE' '_logs'
  New-Item -ItemType Directory -Force -Path $\__logDir | Out-Null
  $\__log = Join-Path $\__logDir ("{0}_{1:yyyy-MM-dd_HHmmss}.log" -f $MyInvocation.MyCommand.Name, (Get-Date))
  Start-Transcript -Path $\__log -Force | Out-Null
} catch { }
. "\_env.ps1"
Param(
  [string]$Root="C:\CHECHA_CORE",
  [string]$AliasName="c07",
  [string]$AliasWeb="c07-web",
  [string]$Bucket="c07-reports",
  [string]$DockerNetwork="checha_core_default",
  [int]$PresignHours=168
)

$ErrorActionPreference = "Stop"
$cfg = Join-Path $Root ".mc"

# 0) Р СџР С•РЎР‚Р С•Р В¶Р Р…РЎвЂ“Р в„– РЎвЂћР В°Р в„–Р В» Р Т‘Р В»РЎРЏ РЎРѓРЎвЂљР Р†Р С•РЎР‚Р ВµР Р…Р Р…РЎРЏ "Р С—Р В°Р С—Р С•Р С”" РЎС“ Р В±Р В°Р С”Р ВµРЎвЂљРЎвЂ“
$empty = Join-Path $Root "tools\.empty"
if (-not (Test-Path $empty)) { New-Item -ItemType File -Path $empty -Force | Out-Null }

Write-Host "==> Layout ensure (weekly/, daily/, dashboards/)"
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/weekly/.keep"     | Out-Null
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/daily/.keep"      | Out-Null
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/dashboards/.keep" | Out-Null

# 1) Р СџР ВµРЎР‚Р ВµР Р…Р ВµРЎРѓРЎвЂљР С‘ Р Р†РЎвЂ“Р Т‘Р С•Р СРЎвЂ“ РЎвЂћР В°Р в„–Р В»Р С‘ РЎС“ РЎРѓР Р†Р С•РЎвЂ” Р С—РЎР‚Р ВµРЎвЂћРЎвЂ“Р С”РЎРѓР С‘
Write-Host "==> Moving known files"
# РЎС“РЎРѓРЎвЂ“ weekly_report_*.md -> weekly/
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" `
  minio/mc find "$AliasName/$Bucket" --name "weekly_report_*.md" --exec "mc mv {} $AliasName/$Bucket/weekly/" | Out-Null

# Р Т‘Р В°РЎв‚¬Р В±Р С•РЎР‚Р Т‘ -> dashboards/
try {
  docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" `
    minio/mc mv "$AliasName/$Bucket/C07_BASE_DASHBOARD.md" "$AliasName/$Bucket/dashboards/C07_BASE_DASHBOARD.md" | Out-Null
} catch { }

# Р Р†РЎРѓРЎвЂ“ C07_report_*.txt -> daily/
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" `
  minio/mc find "$AliasName/$Bucket" --name "C07_report_*.txt" --exec "mc mv {} $AliasName/$Bucket/daily/" | Out-Null

# 2) Р СњР С•РЎР‚Р СР В°Р В»РЎвЂ“Р В·Р В°РЎвЂ РЎвЂ“РЎРЏ Content-Type
Write-Host "==> Normalizing Content-Type"
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" `
  minio/mc find "$AliasName/$Bucket" --name "*.md"   --exec "mc cp --attr 'Content-Type=text/markdown' {} {}" | Out-Null
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" `
  minio/mc find "$AliasName/$Bucket/daily" --name "*.txt" --exec "mc cp --attr 'Content-Type=text/plain' {} {}" | Out-Null

# 3) Р С›Р В±РЎвЂЎР С‘РЎРѓР В»Р С‘РЎвЂљР С‘ Р С—Р С•РЎвЂљР С•РЎвЂЎР Р…Р С‘Р в„– ISO-РЎвЂљР С‘Р В¶Р Т‘Р ВµР Р…РЎРЉ (Р В±Р ВµР В· ISOWeek)
function Get-ISOWeekInfo([datetime]$date){
  $dow = ([int]$date.DayOfWeek + 6) % 7
  $thu = $date.AddDays(3 - $dow)
  $isoYear = $thu.Year
  $jan4 = [datetime]::new($isoYear,1,4)
  $jan4dow = ([int]$jan4.DayOfWeek + 6) % 7
  $firstThu = $jan4.AddDays(3 - $jan4dow)
  $week = 1 + [int](([TimeSpan]($thu - $firstThu)).TotalDays / 7)
  $start = $thu.AddDays(-3).Date
  $end = $start.AddDays(6)
  return @{ Year=$isoYear; Week=$week; Start=$start; End=$end }
}
$iso = Get-ISOWeekInfo (Get-Date)
$weekStr = ("{0}-W{1:D2}" -f $iso.Year,$iso.Week)
$weeklyObj = "weekly/weekly_report_{0}.md" -f $weekStr

# 4) Presign (AliasWeb => Р Т‘Р С•РЎРѓРЎвЂљРЎС“Р С—Р Р…Р С‘Р в„– РЎвЂ“Р В· Windows; 168h = 7 Р Т‘РЎвЂ“Р В±)
function Presign([string]$Object, [switch]$Open){
  $exp = ("{0}h" -f $PresignHours)
  $std = Join-Path $env:TEMP ("presign_" + [guid]::NewGuid() + ".tmp")
  $cmd = @("run","--rm","-v",("$($cfg):/root/.mc"),"minio/mc","share","download","--expire",$exp,("$AliasWeb/$Bucket/$Object"))
  $p = Start-Process -FilePath "docker" -ArgumentList $cmd -NoNewWindow -PassThru -RedirectStandardOutput $std
  $p.WaitForExit()
  $raw = if (Test-Path $std) { Get-Content $std -Raw } else { "" }
  Remove-Item $std -ErrorAction SilentlyContinue
  $link = $null
  if ($raw) {
    $lines = $raw -split "`r?`n"
    foreach($ln in $lines){
      if ($ln -match 'https?://') {
        $m = [regex]::Match($ln,'https?://\S+')
        if ($m.Success) { $link = $m.Value }
      }
    }
  }
  if (-not $link) { return $null }
  $link = $link -replace 'http://host\.docker\.internal:9000','http://localhost:9000'
  if ($Open) {
    Start-Process -FilePath "$env:WINDIR\System32\cmd.exe" -ArgumentList "/c start `"$link`"" -WindowStyle Hidden | Out-Null
  }
  return $link
}

Write-Host "==> Generating presigned links ($PresignHours h)"
$weeklyLink = Presign $weeklyObj -Open
$dashLink   = Presign "dashboards/C07_BASE_DASHBOARD.md"
$kpiLink    = Presign "KPI_TRACKER.md"

$linksDir = Join-Path $Root "C07\_links"
if(-not(Test-Path $linksDir)){ New-Item -ItemType Directory -Force -Path $linksDir | Out-Null }
$out = Join-Path $linksDir "latest.txt"
"Weekly: $weeklyLink`r`nDashboard: $dashLink`r`nKPI: $kpiLink" | Set-Content -Path $out -Encoding UTF8
Set-Clipboard -Value (Get-Content $out -Raw)

Write-Host "==> Done"
Write-Host "Links saved to: $out" -ForegroundColor Green
if($weeklyLink){ Write-Host "Weekly   : $weeklyLink" }
if($dashLink){   Write-Host "Dashboard: $dashLink" }
if($kpiLink){    Write-Host "KPI      : $kpiLink" }
# Auto-open latest links (skip on SYSTEM)
if($env:USERNAME -ne 'SYSTEM'){
  try { & "\C07_open_latest.ps1" } catch { }
}
