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
      git add C07
      git commit -m "C07 baseline v1.0 (2025-08-18) вЂ” deploy"
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

  $mcGlobal = @() ; if ($Insecure) { $mcGlobal += "--insecure" }

  # Try to ensure bucket (ignore failures due to permissions)
  Write-Host "Ensuring bucket $Alias/$Bucket (ignoring errors if no permission)"
  $mbArgs = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"minio/mc") + $mcGlobal + @("mb","--ignore-existing","{0}/{1}" -f $Alias,$Bucket)
  & docker @mbArgs | Out-Null

  # Mount style A: Windows path
  $volA = "$c07`:/data"
  $cpArgsA = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"-v",$volA,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} {0}/{1}/" -f $Alias,$Bucket)
  & docker @cpArgsA
  if ($LASTEXITCODE -eq 0) { Ok "Publish complete via Windows path"; return }

  # Mount style B: //c/ path
  $cAlt = $c07 -replace "^[A-Za-z]:\\","//" + $c07.Substring(0,1).ToLower() + "/" + $c07.Substring(3) -replace "\\","/"
  $volB = "$cAlt`:/data"
  Write-Host "Retrying with alternative mount: $volB"
  $cpArgsB = @("run","--rm","--network",$DockerNetwork,"-v",("$cfgDir`:/root/.mc"),"-v",$volB,"minio/mc") + $mcGlobal + @("find","/data","--name","*.md","--exec","mc cp {} {0}/{1}/" -f $Alias,$Bucket)
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

Write-Host "`n==> Summary"
Write-Host ("Root         : {0}" -f $Root)
Write-Host ("C07 Path     : {0}" -f $c07Path)
Write-Host ("Zip          : {0}" -f $Zip)
Write-Host ("Published    : {0}" -f ([bool]$PublishAfterDeploy))
# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkC35agb3NfzYhzJiGHkz4Qz8
# lAKgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUV7sBqL8Zrzn85t6Y4zinp6prJ/QwDQYJKoZI
# hvcNAQEBBQAEggEAX4umw4duZD2IBaK24jkDGQ6xWi0E3lJGR+dN0bgqSHjlCUeI
# O+RicrIS/svA9Yya7uiDQXIZcY7kYND8ag+22JLFAEBYbUwdiAQU3Ydamw53LLnc
# qc0rWBSuFG/Lqi2Fk0SD+MWNEvjnoKW2WSeZVY5nUjdW1g+AVLn8ZMUe70deB3zs
# nwk+TijptjwwXgfZ+krDXJwu0f3SqnIpRjYeIvud9TEz158UPInoK2FcIAX747M2
# EzfF/obWmhGOCrOrmX0kPxVJ2Wr5gpkGZkrVfTvlMCQKybCxQQmisVNoDrQgIqy7
# 2uOYVYtl83uLYK1uwDVG8B7bgEUInpyWAdhD5w==
# SIG # End signature block

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
