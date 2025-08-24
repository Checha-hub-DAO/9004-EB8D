param([int]$Keep = 8)
$arch = "C:\CHECHA_CORE\C05\Archive"
$log  = "C:\CHECHA_CORE\logs\retention.log"
$null = New-Item -ItemType Directory -Force -Path (Split-Path $log) -ErrorAction SilentlyContinue
# rotate log
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\log_rotate.ps1" -Path $log -MaxKB 512 -Keep 5
$now  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
try {
  if (-not (Test-Path $arch)) { Add-Content -Enc utf8 $log "$now ERROR: archive dir not found: $arch"; exit 1 }
  $files = Get-ChildItem $arch -Filter "C12_*_ReleaseBundle.zip" | Sort-Object LastWriteTime -Descending
  $toDel = $files | Select-Object -Skip $Keep
  if ($toDel) {
    Add-Content -Enc utf8 $log "$now deleting $($toDel.Count) old ZIP(s):"
    $toDel | ForEach-Object { Add-Content -Enc utf8 $log " - $($_.Name)" }
    $toDel | Remove-Item -Force -ErrorAction Stop
  } else {
    Add-Content -Enc utf8 $log "$now nothing to delete (kept=$Keep, total=$($files.Count))"
  }
} catch {
  Add-Content -Enc utf8 $log "$now ERROR: $($_.Exception.Message)"; exit 2
}
