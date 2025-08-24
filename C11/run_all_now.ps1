param(
  [switch]$NoWeekly,
  [switch]$NoAudit,
  [switch]$NoRetention
)

$ErrorActionPreference = 'Stop'
$logs = "C:\CHECHA_CORE\logs"
$arch = "C:\CHECHA_CORE\C05\Archive"
$ok = $true

Write-Host "=== RUN ALL NOW === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Daily
Start-Process -FilePath "C:\CHECHA_CORE\C11\run_daily.cmd" -Wait
"`n--- daily ---"
Get-Content "$logs\vault_bot_daily.log" -Tail 3

# Weekly (ZIP) опційно
if (-not $NoWeekly) {
  Start-Process -FilePath "C:\CHECHA_CORE\C11\run_weekly.cmd" -Wait
  "`n--- weekly ---"
  Get-Content "$logs\vault_bot_weekly.log" -Tail 3
}

# Audit SHA опційно
if (-not $NoAudit) {
  Start-ScheduledTask -TaskName "C11_zip_sha_audit"
  Start-Sleep -Seconds 2
  "`n--- audit ---"
  if (Test-Path "$logs\audit.log") { Get-Content "$logs\audit.log" -Tail 2 }
}

# Retention опційно
if (-not $NoRetention) {
  Start-ScheduledTask -TaskName "C11_archive_retention"
  Start-Sleep -Seconds 1
  "`n--- retention ---"
  if (Test-Path "$logs\retention.log") { Get-Content "$logs\retention.log" -Tail 1 }
}

# Швидкий selfcheck: останній ZIP і відбиття SHA у файлах
$zip = Get-ChildItem $arch -Filter 'C12_*_ReleaseBundle.zip' | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($zip) {
  $rel = $zip.BaseName -replace '_ReleaseBundle$',''
  $sha = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash.ToUpper()
  $A = (Select-String 'C:\CHECHA_CORE\C05\ARCHIVE.md' -Pattern $rel).Line
  $L = (Select-String 'C:\CHECHA_CORE\C03\LOG.md'     -Pattern $rel).Line
  "`nZIP: $($zip.Name)"
  "SHA: $sha"
  "ARCHIVE.md: $A"
  "LOG.md:     $L"
  if ($A -notmatch $sha -or $L -notmatch $sha) { $ok = $false }
}

"`n=== RESULT: " + ($(if ($ok) { "OK" } else { "CHECK FAILED" }))
if (-not $ok) { exit 1 } else { exit 0 }
