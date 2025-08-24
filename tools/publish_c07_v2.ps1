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
  [string]$Bucket = "c07-reports",
  [string]$Endpoint = "http://minio:9000",
  [string]$AccessKey,
  [string]$SecretKey,
  [string]$Profile,                 # optional AWS CLI profile (for AWS CLI path)
  [switch]$UseDockerMc,             # force Dockerized `mc`
  [string]$DockerNetwork = "checha_core_default",
  [switch]$Insecure,                # pass --insecure to mc (self-signed TLS)
  [ValidateSet("","CRC64NVME","CRC32","CRC32C","SHA1","SHA256")]
  [string]$Checksum = ""            # add --checksum to uploads
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
  Info "Using AWS CLI path (supports --include/--exclude)"
  if ($AccessKey -and $SecretKey) {
    $env:AWS_ACCESS_KEY_ID = $AccessKey
    $env:AWS_SECRET_ACCESS_KEY = $SecretKey
  }
  $common = @("--endpoint-url", $Endpoint)
  if ($Profile) { $common = @("--profile", $Profile) + $common }

  Info "Ensuring bucket s3://$Bucket exists"
  try { & aws s3 mb $("s3://$Bucket") @common 2>$null | Out-Null } catch {}
  Info "Uploading only *.md from $c07 to s3://$Bucket/"
  & aws s3 cp $c07 $("s3://$Bucket/") --recursive --exclude "*" --include "*.md" @common
  if ($LASTEXITCODE -ne 0) { Fail "aws s3 cp failed" }
  Ok "Upload complete via AWS CLI"
  exit 0
}

# Fallback: Dockerized MinIO Client (mc). Note: mc cp does NOT support include/exclude filters.
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) { Fail "Neither AWS CLI (aws) nor Docker found. Install one of them or specify -UseDockerMc accordingly." }

if (-not $AccessKey -or -not $SecretKey) { Fail "AccessKey/SecretKey are required for Docker mc path." }
if ($Endpoint -notmatch "^(http|https)://(.+)$") { Fail "Endpoint must start with http:// or https:// (e.g., http://minio:9000)" }

$protoStr     = $Matches[1]
$endpointHost = $Matches[2]

$mcHost = "{0}://{1}:{2}@{3}" -f $protoStr, $AccessKey, $SecretKey, $endpointHost

$mcGlobal = @()
if ($Insecure) { $mcGlobal += "--insecure" }
if ($Checksum) { $mcGlobal += @("--checksum", $Checksum) }

Info "Using Dockerized mc on network '$DockerNetwork'"
$vol = "$c07`:/data"

# 1) Ensure bucket exists
$cmd1 = @("run","--rm","--network",$DockerNetwork,"-e","MC_HOST_local=$mcHost","minio/mc") + $mcGlobal + @("mb","--ignore-existing","local/$Bucket")
& docker @cmd1
if ($LASTEXITCODE -ne 0) { Fail "Failed to create/ensure bucket with mc" }

# 2) Copy only *.md using `mc find --name` + `--exec mc cp {}`
$cmd2 = @("run","--rm","--network",$DockerNetwork,"-e","MC_HOST_local=$mcHost","-v",$vol,"minio/mc") + $mcGlobal + @(
  "find","/data","--name","*.md","--exec","mc cp {} local/$Bucket/"
)
& docker @cmd2
if ($LASTEXITCODE -ne 0) { Fail "mc find/exec cp failed" }

Ok "Upload complete via Dockerized mc (filtered to *.md)"
# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU92bfVftEXm3t464CwSY8CZPn
# EaSgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhDSEVDSEFfQ09SRSBDb2RlIFNpZ25pbmcwHhcNMjUw
# ODE4MDgyMDQ1WhcNMjYwODE4MDg0MDQ1WjAjMSEwHwYDVQQDDBhDSEVDSEFfQ09S
# RSBDb2RlIFNpZ25pbmcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCn
# 268wSei3eEzGU2ZOcUZWesJmYdQ4yIT4J+jVN04WfrsW3JCGWJkXvWMsdoh/hKYF
# yuVSxjKLj9h8jETUrvdTbaRxYSXY6YJCgpZVQBUxEyoWhGWcm0bMsC5eyOfztyZv
# hcy+NZPJrD4nR+Px3VxZt3IBP1zwyw+ubp6HO7zPMW63ne0L/ltftk+Hk3ljSY4H
# D1XziGt6M2b4LLSHAWHrqIwrd0t59UyFUjrtRyYTlXd2aoUcPlOHsREmkLPwJDJC
# uBU7+z5+vt/AWeb0fOVUIoCyRyNXKDYwQMi/mLQV4a5DEjdp22IlwoaPeI21lQhS
# i9FV6Wf8r6976QtRkK+VAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUbg7BB+6svxNMUZRSAuLmrFWh5ckwDQYJ
# KoZIhvcNAQELBQADggEBABo+4rVCqKiS1Gns8FZchJduNcP3Gl9m3HeIb5osxvaf
# rXr0ELgHG8NyGVow1cgScW9efS0n32+USoVoUvb6SfWyMJ8F4a5Bj9cNGd7hvlfD
# zLvbqoRM5kUFvay+rNxVBsc8XmOZwg9/y7kEOYDycgSNjNM6PQZf/hmYxVLdtvQs
# WX133LbWcEOPVmUbHnHVRrFqOZHi379H0O2Cm2Rs7/ubU/Ld04wBGWnqtRBrk6MQ
# I/CsQ7I3mtoXnQlYpUiD9+IXI1A7HKs17a7CZfU67jO8GtRjXNm4BxMz+NBCkz2j
# 6NzzhoXLXl27AtcbdEA1sdsv2NrURC9Y79eQzYpiY+cxggHYMIIB1AIBATA3MCMx
# ITAfBgNVBAMMGENIRUNIQV9DT1JFIENvZGUgU2lnbmluZwIQdJVhwAGQr7pIn6GC
# jBUmjzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUl1w7uLpSmuAFLT+JdFXWYlCu7eMwDQYJKoZI
# hvcNAQEBBQAEggEAdTWmz+uZ6v/EGoJyHxzZ+FYsEb6eXayIERuIhp8JbUA/1wcP
# xmopJLxEYA4aQ+VyXBUOyOlzvl2nlZXORNee2UnRtt8bFRAx+kRVMIPlyt9kK+uO
# 0UlF/9vShD7cksHiqYnXdjboP55IvaWhUXuO1aJTj22KaH5f7OqPonJ5jwLW9GUr
# /64xiucNTD8NuJ3L7lYaE+Ec2BTn5U91PSsmsfh5h6g+5xbZwkDtjKtDhCIbaWen
# FfvsBw6X2eN5WJMxG2JLZSrB+bwspOzk2wcAmliUqRv8I1b9V5Avypa90SJnoTPH
# 6OX58Id/3/HVbDBd5gtT/2Dr6USgOqVP8M2zJQ==
# SIG # End signature block

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
