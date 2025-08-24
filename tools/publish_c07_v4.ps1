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
  [string]$AliasName = "local",
  [switch]$Insecure
)

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Fail($m){ Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# Validate
$c07 = Join-Path $Root "C07"
if (-not (Test-Path $c07)) { Fail "Path not found: $c07" }

# mc config dir (persist alias across runs)
$cfgDir = Join-Path $Root ".mc"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) { Fail "Docker not found in PATH" }

# Global flags
$mcGlobal = @()
if ($Insecure) { $mcGlobal += "--insecure" }

# Helper: run mc with mounted config
function Mc($args) {
  $full = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"minio/mc") + $mcGlobal + $args
  & docker @full
  return $LASTEXITCODE
}

# 0) If keys provided вЂ” set alias. Otherwise, ensure alias exists.
if ($AccessKey -and $SecretKey) {
  Info "Setting mc alias '$AliasName' for $Endpoint"
  $rc = Mc @("alias","set",$AliasName,$Endpoint,$AccessKey,$SecretKey)
  if ($rc -ne 0) { Fail "mc alias set failed" }
} else {
  Info "No keys provided вЂ” trying existing alias '$AliasName'"
  $rc = Mc @("alias","list",$AliasName)
  if ($rc -ne 0) {
    Fail "Alias '$AliasName' not found. Provide -AccessKey and -SecretKey or create the alias manually."
  }
}

# 1) Quick connectivity check (may return AccessDenied if policy forbids ListBuckets)
Info "Checking connectivity with 'mc ls $AliasName' (ignore AccessDenied if policy restricted)"
$rc = Mc @("ls",$AliasName)
if ($rc -ne 0) {
  Warn "mc ls failed (possibly AccessDenied). Proceeding to create/use bucket '$Bucket' anyway."
}

# 2) Ensure bucket exists
Info "Ensuring bucket $AliasName/$Bucket exists"
$rc = Mc @("mb","--ignore-existing","{0}/{1}" -f $AliasName,$Bucket)
if ($rc -ne 0) {
  Fail "mc mb failed вЂ” likely due to insufficient permissions or wrong credentials."
}

# 3) Upload only *.md from C07 using find --exec cp
Info "Uploading *.md from $c07 to $AliasName/$Bucket"
$rc = (& docker run --rm --network $DockerNetwork -v "$($cfgDir):/root/.mc" -v "$($c07):/data" minio/mc @($mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} {0}/{1}/" -f $AliasName,$Bucket)))
if ($LASTEXITCODE -ne 0) { Fail "mc find/exec cp failed" }

Ok "Publish complete"
# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqeX1nI/GeWl6l8qwvIRSRWly
# 3cCgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQU9U83GZcYI3gk9bwGXgYhmv3BwwswDQYJKoZI
# hvcNAQEBBQAEggEAEj4HenmcbfZ7jGVbu5eZvNwHhjTBaypZ1z9+pUKJUswt6ZD2
# aO+Hz+L6Ndi6ibC91idabOTt4AQaqIFFNVEBEiBJAApUflwcx3WHSKz/LXPpoL3x
# gPQ8K0nAQ/NpCg0RYeHdDsx4RGqr3zVnQvIABKco+yINLd8fDMDgiqgGMqwqoPp0
# l4sqX8cCiT/Lhg2W1WLfliqn7V5fpPqNJ0kimXywKwoPlSJ+9gOngvLwTsGh3Db3
# fkKaPTQbzQ48xW5rqlCl7WJT8YkyOyi4Hhhupe6qzT3y9FblZeKuveEjyPHhsVCU
# fN+ehLQQ/XzdkF29PmE8+AUdHz6btmg8ej4/xw==
# SIG # End signature block


# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
