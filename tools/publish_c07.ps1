Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$Bucket = "c07-reports",
  [string]$Endpoint = "http://minio:9000",
  [string]$AccessKey,
  [string]$SecretKey,
  [string]$Profile,                 # optional AWS CLI profile
  [switch]$UseDockerMc,             # force Docker mc path
  [string]$DockerNetwork = "checha_core_default"
)

function Info($msg){ Write-Host $msg -ForegroundColor Cyan }
function Ok($msg){ Write-Host $msg -ForegroundColor Green }
function Warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function Fail($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$c07 = Join-Path $Root "C07"
if (-not (Test-Path $c07)) { Fail "Path not found: $c07" }

# Normalize endpoint (remove trailing slash)
if ($Endpoint.EndsWith("/")) { $Endpoint = $Endpoint.TrimEnd("/") }

# Try AWS CLI first unless user forces Docker mc
$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($aws -and -not $UseDockerMc) {
  Info "Using AWS CLI path"
  if ($AccessKey -and $SecretKey) {
    $env:AWS_ACCESS_KEY_ID = $AccessKey
    $env:AWS_SECRET_ACCESS_KEY = $SecretKey
  }
  $common = @("--endpoint-url", $Endpoint)

  if ($Profile) { $common = @("--profile", $Profile) + $common }

  Info "Ensuring bucket s3://$Bucket exists"
  try { & aws s3 mb $("s3://$Bucket") @common 2>$null | Out-Null } catch {}
  Info "Uploading *.md from $c07 to s3://$Bucket/"
  & aws s3 cp $c07 $("s3://$Bucket/") --recursive --exclude "*" --include "*.md" @common
  if ($LASTEXITCODE -ne 0) { Fail "aws s3 cp failed" }
  Ok "Upload complete via AWS CLI"
  exit 0
}

# Fallback: Dockerized MinIO Client (mc)
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) { Fail "Neither AWS CLI (aws) nor Docker found. Install one of them or don't use -UseDockerMc." }

if (-not $AccessKey -or -not $SecretKey) { Fail "AccessKey/SecretKey are required for Docker mc path." }

if ($Endpoint -notmatch "^(http|https)://") { Fail "Endpoint must start with http:// or https://" }
$proto = $matches[1]
$host = $Endpoint.Substring($Endpoint.IndexOf("://") + 3)

$mcHost = "{0}://{1}:{2}@{3}" -f $proto, $AccessKey, $SecretKey, $host

Info "Using Dockerized mc on network '$DockerNetwork'"
$vol = "$c07`:/data"

# Ensure bucket exists
$cmd1 = @("run","--rm","--network",$DockerNetwork,"-e","MC_HOST_local=$mcHost","minio/mc","mb","--ignore-existing","local/$Bucket")
& docker @cmd1
if ($LASTEXITCODE -ne 0) { Fail "Failed to create/ensure bucket with mc" }

# Copy only *.md without relying on shell wildcards
$cmd2 = @("run","--rm","--network",$DockerNetwork,"-e","MC_HOST_local=$mcHost","-v",$vol,"minio/mc","cp","--recursive","--exclude","*","--include","*.md","/data","local/$Bucket/")
& docker @cmd2
if ($LASTEXITCODE -ne 0) { Fail "mc cp failed" }

Ok "Upload complete via Dockerized mc"