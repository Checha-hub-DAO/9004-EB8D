param([string]$Root="C:\CHECHA_CORE")
function Say([string]$m){ Write-Host "[ARCH] $m" }

# ENV / paths
$envFile = Join-Path $Root "CHECHA.env.ps1"; if (Test-Path $envFile) { . $envFile }
$off = if ($env:CHECHA_OFFSITE_PATH) { $env:CHECHA_OFFSITE_PATH } else { Join-Path (Split-Path $Root -Qualifier) "CHECHA_OFFSITE" }
$logDir = Join-Path $Root "C03"; if (!(Test-Path $logDir)){ New-Item $logDir -ItemType Directory -Force | Out-Null }
$log = Join-Path $logDir "LOG.md"; if (!(Test-Path $log)){"# New LOG.md (init)" | Out-File -FilePath $log -Encoding UTF8}
$arcRoot = Join-Path $Root "C05\Archive"; if (!(Test-Path $arcRoot)){ New-Item $arcRoot -ItemType Directory -Force | Out-Null }

$day    = (Get-Date).ToString("yyyy-MM-dd")
$dayDir = Join-Path $arcRoot $day; if (!(Test-Path $dayDir)){ New-Item $dayDir -ItemType Directory -Force | Out-Null }

# REPORT + SHA
$report = Join-Path $dayDir ("REPORT_" + $day + ".json")
@{ day=$day; root=$Root; offsite=$off } | ConvertTo-Json -Depth 5 | Out-File -FilePath $report -Encoding UTF8
(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash + "  " + (Split-Path -Leaf $report) | Out-File -FilePath ($report + ".sha256") -Encoding ASCII

# ZIP build (PS5-safe)
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$zip = Join-Path $dayDir ("SNAPSHOT_" + $day + ".zip")
if (Test-Path $zip) { Remove-Item $zip -Force }

$src = Join-Path $Root "C02\INBOX"
$hasInbox = (Test-Path $src) -and ((Get-ChildItem -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
function New-PlaceholderZip([string]$target){
  $tmp = Join-Path (Split-Path $target -Parent) "__tmp_empty"
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  "No INBOX; placeholder" | Out-File -FilePath (Join-Path $tmp "PLACEHOLDER.txt") -Encoding ASCII
  [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $target)
  Remove-Item $tmp -Recurse -Force
}

if ($hasInbox) { [System.IO.Compression.ZipFile]::CreateFromDirectory($src, $zip) } else { New-PlaceholderZip $zip }

# Verify ZIP (ZipFile.OpenRead with COM fallback)
$zipOK = $true
try {
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  $z = [IO.Compression.ZipFile]::OpenRead($zip); $null=$z.Entries.Count; $z.Dispose()
} catch { $zipOK = $false }
if (-not $zipOK) {
  try {
    $sh = New-Object -ComObject Shell.Application
    $ns = $sh.Namespace($zip)
    if (-not ($ns -and $ns.Items().Count -ge 1)) { throw "COM open failed" }
  } catch {
    try { New-PlaceholderZip $zip } catch {}
  }
}
# SHA256 sidecar
(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash + "  " + (Split-Path -Leaf $zip) | Out-File -FilePath ($zip + ".sha256") -Encoding ASCII

# Offsite + verify JSON copy
if (!(Test-Path $off)) { New-Item -Path $off -ItemType Directory -Force | Out-Null }
$offDay = Join-Path $off $day; if (!(Test-Path $offDay)) { New-Item -Path $offDay -ItemType Directory -Force | Out-Null }
Copy-Item $dayDir\* $offDay -Force

$ok = $true
try {
  $srcJ = (Get-Content -Raw -LiteralPath ($report + ".sha256")).Split()[0]
  $dstJ = (Get-FileHash -LiteralPath (Join-Path $offDay (Split-Path -Leaf $report)) -Algorithm SHA256).Hash
  if ($srcJ -ne $dstJ){ $ok = $false }
} catch { $ok = $false }

$state = if($ok){"OK"} else {"FAIL"}
Add-Content -Path $log -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | auto-archive | " + $state + " |") -Encoding UTF8
Say ("auto-archive -> " + $state)

