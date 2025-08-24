param(
    [string]$Root = "D:\CHECHA_CORE",
    [Parameter(Mandatory=$true)]
    [string]$BundlePath
)
function Write-Step($m){ Write-Host ("[PUBLISH] " + $m) }
function Ensure-Dir([string]$p){ if(-not (Test-Path $p)){ New-Item -Path $p -ItemType Directory -Force | Out-Null } }

# Verify source
if (-not (Test-Path $BundlePath)) { throw "Bundle not found: $BundlePath" }
$srcHash = (Get-FileHash -LiteralPath $BundlePath -Algorithm SHA256).Hash
Write-Step ("Source SHA256: " + $srcHash)

# Local DIST
$dist = Join-Path $Root "C03\DIST"; Ensure-Dir $dist
$dst = Join-Path $dist (Split-Path -Leaf $BundlePath)
Copy-Item -LiteralPath $BundlePath -Destination $dst -Force
$locHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
Write-Step ("Local copy SHA256: " + $locHash + " (equal=" + ($srcHash -eq $locHash) + ")")

# Sidecar
$shaFile = $dst + ".sha256"
"$srcHash  $(Split-Path -Leaf $dst)" | Out-File -FilePath $shaFile -Encoding ASCII

# Offsite (if enabled)
$envFile = Join-Path $Root "CHECHA.env.ps1"; if (Test-Path $envFile) { . $envFile }
$off = $env:CHECHA_OFFSITE_PATH
$enabled = ($env:CHECHA_OFFSITE_ENABLED -eq "1")
if ($enabled -and $off) {
    $offDist = Join-Path $off "DIST"; Ensure-Dir $offDist
    $offDst = Join-Path $offDist (Split-Path -Leaf $BundlePath)
    Copy-Item -LiteralPath $BundlePath -Destination $offDst -Force
    $offHash = (Get-FileHash -LiteralPath $offDst -Algorithm SHA256).Hash
    Write-Step ("Offsite copy SHA256: " + $offHash + " (equal=" + ($srcHash -eq $offHash) + ")")
    "$srcHash  $(Split-Path -Leaf $offDst)" | Out-File -FilePath ($offDst + ".sha256") -Encoding ASCII
}

# Log
$log = Join-Path $Root "C03\LOG.md"; if(-not (Test-Path $log)){ "# New LOG.md (init)" | Out-File -FilePath $log -Encoding UTF8 }
Add-Content -Path $log -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | publish-bundle | " + (Split-Path -Leaf $dst) + " |") -Encoding UTF8
