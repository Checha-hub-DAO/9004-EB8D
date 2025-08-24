param(
    [string]$Root = "D:\CHECHA_CORE",
    [switch]$Force
)
function Write-Step($m){ Write-Host ("[LOGROTATE] " + $m) }
$now = Get-Date
if (-not $Force) {
    if ($now.Day -ne 1) { Write-Step "Not the 1st day — nothing to do."; exit 0 }
}

$logDir = Join-Path $Root "C03"
$log = Join-Path $logDir "LOG.md"
if (-not (Test-Path $log)) { Write-Step "LOG.md not found — nothing to rotate."; exit 0 }

# If forced: rotate current month; else (on day=1): rotate previous month
$stamp = if ($Force) { $now.ToString("yyyy-MM") } else { $now.AddMonths(-1).ToString("yyyy-MM") }
$dst = Join-Path $logDir ("LOG_" + $stamp + ".md")
if (Test-Path $dst) {
    $dst = Join-Path $logDir ("LOG_" + $stamp + "_" + $now.ToString("HHmmss") + ".md")
    Write-Step ("Destination existed; using: " + $dst)
}
try {
    Move-Item -LiteralPath $log -Destination $dst -Force
    "# New LOG.md (rotated on {0})`r`n" -f $now.ToString("yyyy-MM-dd HH:mm:ss") | Out-File -FilePath $log -Encoding UTF8
    Write-Step ("Rotated to " + $dst)
} catch {
    Write-Step ("ERROR: rotation failed — " + $_.Exception.Message)
}
