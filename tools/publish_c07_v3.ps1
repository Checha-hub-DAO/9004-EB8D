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
  [string]$DockerNetwork = "checha_core_default",
  [switch]$Insecure
)

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Fail($m){ Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# Validate
$c07 = Join-Path $Root "C07"
if (-not (Test-Path $c07)) { Fail "Path not found: $c07" }
if (-not $AccessKey -or -not $SecretKey) { Fail "Provide -AccessKey and -SecretKey" }
if ($Endpoint -notmatch "^(http|https)://(.+)$") { Fail "Endpoint must start with http:// or https:// (e.g., http://minio:9000)" }

# Prepare mc config dir (persist alias across runs)
$cfgDir = Join-Path $Root ".mc"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) { Fail "Docker not found in PATH" }

# Global flags
$mcGlobal = @()
if ($Insecure) { $mcGlobal += "--insecure" }

# 1) Set alias (persisted via mounted /root/.mc)
Info "Setting mc alias 'local' for $Endpoint"
$aliasArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"minio/mc") + $mcGlobal + @("alias","set","local",$Endpoint,$AccessKey,$SecretKey)
& docker @aliasArgs
if ($LASTEXITCODE -ne 0) { Fail "mc alias set failed" }

# 2) Ensure bucket exists
Info "Ensuring bucket local/$Bucket exists"
$mbArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"minio/mc") + $mcGlobal + @("mb","--ignore-existing","local/$Bucket")
& docker @mbArgs
if ($LASTEXITCODE -ne 0) { Fail "mc mb failed" }

# 3) Copy only *.md using find --exec mc cp
Info "Uploading *.md from $c07 to local/$Bucket"
$cpArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"-v",("$c07`:/data"),"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} local/$Bucket/")
& docker @cpArgs
if ($LASTEXITCODE -ne 0) { Fail "mc find/exec cp failed" }

Ok "Publish complete"
# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuvhyrrCGb/V4vaqptcm+GnEm
# KIGgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUT0qL1SSeR7kAMbcfeVgKZMZMk3MwDQYJKoZI
# hvcNAQEBBQAEggEAZ1qhvJzOo8G/JGUgSoC52uZnkkD/oZEm2LwkKU7m7VMnxVO0
# 5Z3z1c73BwA4iQovif6YNMmmSvOXCv8d6mayWV9oGifcwGLJUbz/kBWTh/d7O+qd
# 0PVSMCMJWufucCWsD72mk/UTFKwjIrpxUc9tk+wXvpc5RZxLQz1nP5P5Sc/rG2A7
# dfP4atQR/Nq7VJQsTmbjcgFd+znqz36DWhVRqS5K4B1P0I5gD9KgC/jD5b3nzWm3
# maMQgOj+HRbg2tubCkiWjHFBjoM7xcOzJzxZ1rg4Vy018G9j9lONGLa3U15X8zww
# iinpgk4LEz3pa9SnmYJLyJsUm9A01WeXsceNXQ==
# SIG # End signature block

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
