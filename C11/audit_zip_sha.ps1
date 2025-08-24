$archFile = "C:\CHECHA_CORE\C05\ARCHIVE.md"
$logFile  = "C:\CHECHA_CORE\logs\audit.log"
$zipDir   = "C:\CHECHA_CORE\C05\Archive"
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
# rotate
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\log_rotate.ps1" -Path $logFile -MaxKB 512 -Keep 5
if (-not (Test-Path $archFile) -or -not (Test-Path $zipDir)) { Add-Content -Enc utf8 $logFile "$now ERROR: missing $archFile or $zipDir"; exit 1 }
$rows = (Get-Content $archFile -Raw) -split "`r?`n"
$idx = @{}
for ($i=0; $i -lt $rows.Count; $i++) {
  if ($rows[$i] -match '^\|\s*\d{4}-\d{2}-\d{2}\s*\|\s*(C12_[^|]+)_ReleaseBundle\s*\|') { $idx[$matches[1]]=$i }
}
$changed = 0
Get-ChildItem $zipDir -Filter "C12_*_ReleaseBundle.zip" | ForEach-Object {
  $rel = $_.BaseName -replace '_ReleaseBundle$',''
  if (-not $idx.ContainsKey($rel)) { return }
  $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToUpper()
  $i = $idx[$rel]
  if ($rows[$i] -notmatch [regex]::Escape($sha)) {
    $rows[$i] = ($rows[$i] -replace '\|\s*([0-9A-Fa-f\-]{1,64})\s*\|$', "| $sha |"); $changed++
  }
}
if ($changed -gt 0) { Set-Content -Enc utf8 $archFile ($rows -join "`r`n"); Add-Content -Enc utf8 $logFile "$now FIXED $changed SHA mismatch(es)" }
else { Add-Content -Enc utf8 $logFile "$now OK no SHA mismatches" }
# mirror to LOG.md
$logMd  = "C:\CHECHA_CORE\C03\LOG.md"
if (Test-Path $logMd) {
  $rowsA = (Get-Content $archFile -Raw) -split "`r?`n"
  $rowsL = (Get-Content $logMd   -Raw) -split "`r?`n"
  foreach ($r in $rowsA) {
    if ($r -match '^\|\s*\d{4}-\d{2}-\d{2}\s*\|\s*(C12_[^|]+)_ReleaseBundle.*\|\s*([0-9A-Fa-f\-]{1,64})\s*\|$') {
      $rel=$matches[1]; $sha=$matches[2]
      for ($i=0; $i -lt $rowsL.Count; $i++) {
        if ($rowsL[$i] -like "*$rel*_ReleaseBundle*") {
          $rowsL[$i] = ($rowsL[$i] -replace '\|\s*([0-9A-Fa-f\-]{1,64})\s*\|$', "| $sha |"); break
        }
      }
    }
  }
  Set-Content -Enc utf8 $logMd ($rowsL -join "`r`n")
}
