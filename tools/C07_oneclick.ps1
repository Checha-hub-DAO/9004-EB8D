param(
  [string]$Root          = "C:\CHECHA_CORE",
  [string]$Alias         = "c07",
  [string]$AliasWeb      = "c07-web",
  [string]$Bucket        = "c07-reports",
  [string]$DockerNetwork = "checha_core_default",
  [int]   $ExpireSec     = 604800
)

$ErrorActionPreference = "Stop"

function Mc([string[]]$Args){
  $cfg = Join-Path $Root ".mc"
  if(-not (Test-Path $cfg)){ throw "MinIO mc config not found: $cfg" }
  $cfgMount = "$($cfg):/root/.mc"
  & docker run --rm --network $DockerNetwork -v $cfgMount minio/mc @Args
}

function Get-LatestWeeklyKey {
  $results = @()
  foreach($prefix in @("weekly","")){
    $out = ""
    try { $out = Mc @("find","$Alias/$Bucket/$prefix","--name","weekly_report_*.md","--json") } catch {}
    if($out){
      foreach($line in ($out -split "`r?`n")){
        if([string]::IsNullOrWhiteSpace($line)){ continue }
        try { $o = $line | ConvertFrom-Json } catch { $o = $null }
        if($o -and $o.type -eq "file"){
          $key = $null
          if($o.PSObject.Properties['key']){ $key = $o.key } elseif($o.PSObject.Properties['name']){ $key=$o.name }
          if($key){ $results += [pscustomobject]@{ key=$key; last=[datetime]$o.lastModified } }
        }
      }
    }
    if($results.Count){ break }
  }
  if(-not $results.Count){ return $null }
  ($results | Sort-Object last | Select-Object -Last 1).key
}

function PresignKey([string]$key){
  foreach($al in @($AliasWeb,$Alias)){
    try{
      $obj = "$al/$Bucket/$key"
      $out = Mc @("share","download","--expire",$ExpireSec.ToString(),$obj)
      $url = $out -split "`r?`n" | Where-Object {$_ -match "https?://"} |
             ForEach-Object { $_ -replace '^(URL|Share):\s*','' } | Select-Object -Last 1
      if($url){ return $url.Trim() }
    }catch{}
  }
  throw "Presign failed: $key"
}

# 1) знайти свіжий weekly (в weekly/ або в корені)
$weeklyKey = Get-LatestWeeklyKey
if(-not $weeklyKey){ throw "No weekly report found under $Alias/$Bucket (weekly/ or root)" }

# 2) presign для weekly, dashboard, kpi
$weeklyUrl = PresignKey $weeklyKey
$dashUrl   = PresignKey "dashboards/C07_BASE_DASHBOARD.md"
$kpiUrl    = PresignKey "KPI_TRACKER.md"

# 3) зберегти у latest.txt й відкрити
$linksDir  = Join-Path $Root "C07\_links"
$linksFile = Join-Path $linksDir "latest.txt"
New-Item -ItemType Directory -Force -Path $linksDir | Out-Null

@"
Weekly   : $weeklyUrl
Dashboard: $dashUrl
KPI      : $kpiUrl
"@ | Set-Content -Encoding ASCII $linksFile

Write-Host ("Links saved to: {0}" -f $linksFile) -ForegroundColor Green
Write-Host "Weekly   : $weeklyUrl"
Write-Host "Dashboard: $dashUrl"
Write-Host "KPI      : $kpiUrl"

if ($weeklyUrl) { Start-Process $weeklyUrl }
if ($dashUrl)   { Start-Process $dashUrl }
if ($kpiUrl)    { Start-Process $kpiUrl }