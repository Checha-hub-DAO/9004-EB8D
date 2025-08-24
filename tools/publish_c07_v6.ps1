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
  [string]$Bucket="c07-reports",
  [string]$DockerNetwork="checha_core_default",
  [string]$ContentType="text/markdown; charset=utf-8"
)
$ErrorActionPreference="Stop"

function Ensure-Dir($p){ if(-not(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$cfg  = Join-Path $Root ".mc"; Ensure-Dir $cfg
$c07  = Join-Path $Root "C07"
if(-not(Test-Path $c07)){ throw "Path not found: $c07" }

# Перебір локальних .md (без mc find/format-ловушок)
$files = Get-ChildItem -LiteralPath $c07 -Filter *.md -File
if($files.Count -eq 0){ Write-Host "No .md files in $c07"; exit 0 }

foreach($f in $files){
  $name = $f.Name
  & docker run --rm --network $DockerNetwork `
    -v "$($cfg):/root/.mc" -v "$($c07):/data" `
    minio/mc cp --attr "Content-Type=$ContentType" "/data/$name" "$AliasName/$Bucket/$name"
  if($LASTEXITCODE -ne 0){ throw "mc cp failed for $name" }
  Write-Host "Uploaded: $name" -ForegroundColor Green
}

Write-Host "Publish complete" -ForegroundColor Green

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
