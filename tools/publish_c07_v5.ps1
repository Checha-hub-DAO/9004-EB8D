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
  [string]$DockerNetwork = "checha_core_default",
  [switch]$Insecure
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
  return ("//{0}/{1}" -f $drive, $rest)
}

$cfgDir = Join-Path $Root ".mc" ; Ensure-Path $cfgDir
$c07    = Join-Path $Root "C07"
if (-not (Test-Path $c07)) { Fail ("Path not found: {0}" -f $c07) }

$mcGlobal = @()
if ($Insecure) { $mcGlobal += "--insecure" }

# Ensure bucket (ignore if exists)
Info ("Ensuring bucket {0}/{1}" -f $AliasName, $Bucket)
$mbArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$($cfgDir):/root/.mc"),"minio/mc") + $mcGlobal + @("mb","--ignore-existing",("{0}/{1}" -f $AliasName,$Bucket))
& docker @mbArgs | Out-Null

# Prepare destination once (щоб уникнути -f з '{}')
$dest = ("{0}/{1}/" -f $AliasName,$Bucket)
$exec = "mc cp {} $dest"

# Attempt Windows drive mount
$volA = "$($c07):/data"
$cpArgsA = @("run","--rm","--network",$DockerNetwork,"-v",("$($cfgDir):/root/.mc"),"-v",$volA,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec",$exec)
& docker @cpArgsA
if ($LASTEXITCODE -eq 0) { Ok "Publish complete via Windows path"; exit 0 }

# Retry with //c/ mount
$alt = Convert-To-AltMount $c07
$volB = "$($alt):/data"
Warn ("Retrying with alternative mount: {0}" -f $volB)
$cpArgsB = @("run","--rm","--network",$DockerNetwork,"-v",("$($cfgDir):/root/.mc"),"-v",$volB,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec",$exec)
& docker @cpArgsB
if ($LASTEXITCODE -ne 0) { Fail "Publish failed (both mount styles)." }
Ok "Publish complete via //c/ mount"

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
