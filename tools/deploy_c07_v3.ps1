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
  [string]$Zip  = "$PSScriptRoot\CHECHA_CORE_C07_BASELINE_v1.0_2025-08-18.zip",
  [switch]$GitCommit,

  # --- Publishing options ---
  [switch]$PublishAfterDeploy,
  [string]$PublishAlias = "c07",
  [string]$PublishBucket = "c07-reports",
  [string]$PublishDockerNetwork = "checha_core_default",
  [switch]$PublishInsecure
)

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Fail($m){ Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

function Ensure-Path([string]$p){
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Convert-To-AltMount([string]$winPath){
  # C:\CHECHA_CORE\C07 -> //c/CHECHA_CORE/C07
  $drive = $winPath.Substring(0,1).ToLower()
  $rest  = $winPath.Substring(3).Replace('\','/')
  return "//$drive/$rest"
}

function Deploy-C07 {
  param([string]$Root, [string]$Zip, [switch]$GitCommit)

  if (-not (Test-Path $Root)) { Fail "Root not found: $Root" }
  if (-not (Test-Path $Zip))  { Fail "ZIP not found: $Zip" }

  $date = (Get-Date -Format "yyyy-MM-dd")
  $time = (Get-Date -Format "HHmmss")
  $arcDir = Join-Path $Root ("C05\Archive\{0}" -f $date) ; Ensure-Path $arcDir

  $c07Path = Join-Path $Root "C07"
  if (Test-Path $c07Path) {
    $backupZip = Join-Path $arcDir ("C07_backup_{0}.zip" -f $time)
    Write-Host "Backing up existing C07 -> $backupZip"
    if (Test-Path (Join-Path $c07Path "*")) {
      Compress-Archive -Path (Join-Path $c07Path "*") -DestinationPath $backupZip -Force
    } else {
      Set-Content -Path (Join-Path $arcDir ("C07_backup_{0}.txt" -f $time)) -Value "C07 was empty"
    }
  } else {
    New-Item -ItemType Directory -Force -Path $c07Path | Out-Null
  }

  Write-Host "Deploying C07 from ZIP: $Zip"
  $tmp = Join-Path $env:TEMP ("C07_tmp_{0}" -f $time)
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  Expand-Archive -Path $Zip -DestinationPath $tmp -Force
  Copy-Item -Path (Join-Path $tmp "C07\*") -Destination $c07Path -Recurse -Force
  Remove-Item $tmp -Recurse -Force

  Ok "C07 deployed to $c07Path"

  if (Test-Path (Join-Path $Root ".git")) {
    if ($GitCommit) {
      Push-Location $Root
      git add C07 | Out-Null
      git commit -m "C07 baseline v1.0 (2025-08-18) вЂ” deploy" | Out-Null
      Pop-Location
      Ok "Git commit created."
    } else {
      Warn "Git repo detected. Use -GitCommit to auto-commit."
    }
  }

  return $c07Path
}

function Publish-C07-WithAlias {
  param(
    [string]$Root,
    [string]$Alias,
    [string]$Bucket,
    [string]$DockerNetwork,
    [switch]$Insecure
  )

  $cfgDir = Join-Path $Root ".mc" ; Ensure-Path $cfgDir
  $c07 = Join-Path $Root "C07"
  if (-not (Test-Path $c07)) { Fail "Path not found: $c07" }

  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) { Fail "Docker not found in PATH" }

  $mcGlobal = @()
  if ($Insecure) { $mcGlobal += "--insecure" }

  # Try to ensure bucket (ignore failures due to permissions)
  Write-Host "Ensuring bucket $Alias/$Bucket (ignoring errors if no permission)"
  $mbArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"minio/mc") + $mcGlobal + @("mb","--ignore-existing","$Alias/$Bucket")
  & docker @mbArgs | Out-Null

  # Attempt Windows drive mount
  $volA = "$c07`:/data"
  $cpArgsA = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"-v",$volA,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} $Alias/$Bucket/")
  & docker @cpArgsA
  if ($LASTEXITCODE -eq 0) { Ok "Publish complete via Windows path"; return }

  # Retry with //c/ mount
  $alt = Convert-To-AltMount $c07
  $volB = "$alt`:/data"
  Write-Host "Retrying with alternative mount: $volB"
  $cpArgsB = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"-v",$volB,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} $Alias/$Bucket/")
  & docker @cpArgsB
  if ($LASTEXITCODE -ne 0) { Fail "Publish failed (both mount styles)." }
  Ok "Publish complete via //c/ mount"
}

# === Main ===
$c07Path = Deploy-C07 -Root $Root -Zip $Zip -GitCommit:$GitCommit
if ($PublishAfterDeploy) {
  Info "Publishing after deploy using alias '$PublishAlias' to bucket '$PublishBucket'..."
  Publish-C07-WithAlias -Root $Root -Alias $PublishAlias -Bucket $PublishBucket -DockerNetwork $PublishDockerNetwork -Insecure:$PublishInsecure
}

Write-Host ""
Write-Host "==> Summary"
Write-Host ("Root         : " + $Root)
Write-Host ("C07 Path     : " + $c07Path)
Write-Host ("Zip          : " + $Zip)
Write-Host ("Published    : " + [bool]$PublishAfterDeploy)
# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
