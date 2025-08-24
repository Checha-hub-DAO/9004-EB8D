param(
    [string]$Root = "D:\CHECHA_CORE",
    [string]$Bundle,                # optional: path to ChechaCore_v*.zip
    [switch]$DryRun,
    [switch]$Silent                 # suppress Write-Host except fatal
)
function Say($m){ if(-not $Silent){ Write-Host "[UPDATE] $m" } }
function Ensure-Dir([string]$p){ if(-not (Test-Path $p)){ New-Item -Path $p -ItemType Directory -Force | Out-Null } }

# Init log
$logDir = Join-Path $Root "C03"; Ensure-Dir $logDir
$log = Join-Path $logDir "LOG.md"; if(-not (Test-Path $log)){ "# New LOG.md (init)" | Out-File -FilePath $log -Encoding UTF8 }

# Pick bundle
$dist = Join-Path $logDir "DIST"; Ensure-Dir $dist
if (-not $Bundle) {
    $cand = Get-ChildItem -LiteralPath $dist -File -Filter "ChechaCore_v*.zip" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($cand) { $Bundle = $cand.FullName }
}
if (-not $Bundle -or -not (Test-Path $Bundle)) { Say "Bundle not found."; exit 1 }
Say ("Using bundle: " + $Bundle)

# Extract to TMP
$tmpRoot = Join-Path $logDir "TMP"; Ensure-Dir $tmpRoot
$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$dst = Join-Path $tmpRoot ("UPDATE_" + $stamp); Ensure-Dir $dst
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Bundle, $dst, $true)
    Say ("Extracted to: " + $dst)
} catch {
    Say ("Extract failed: " + $_.Exception.Message); exit 1
}

# Find installer
$inst = Get-ChildItem -LiteralPath $dst -Recurse -File -Filter "ChechaCore-Deploy-INSTALLER-*.ps1" | Sort-Object Name -Descending | Select-Object -First 1
if (-not $inst) { Say "Installer not found inside bundle."; exit 1 }

# Run installer (files only, no schedules)
if ($DryRun) {
    Say ("DRY-RUN: would run installer: " + $inst.FullName + " -Root `"$Root`" -AutoLog")
} else {
    try {
        Say ("Running installer: " + $inst.Name)
        powershell -NoProfile -ExecutionPolicy Bypass -File $inst.FullName -Root $Root -AutoLog
        $code = $LASTEXITCODE
        if ($code -ne 0) { Say ("Installer exit code: " + $code) }
    } catch {
        Say ("Installer run failed: " + $_.Exception.Message)
    }
}

# Move bundle to APPLIED
$appliedDir = Join-Path $dist "APPLIED"; Ensure-Dir $appliedDir
$dstBundle = Join-Path $appliedDir (Split-Path -Leaf $Bundle)
try { Move-Item -LiteralPath $Bundle -Destination $dstBundle -Force } catch { }

# Log
Add-Content -Path $log -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | update-from-bundle | " + (Split-Path -Leaf $dst) + " |") -Encoding UTF8
exit 0
