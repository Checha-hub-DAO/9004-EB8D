param([string]$Root = "C:\CHECHA_CORE")
function Say($m){ Write-Host "[RESTORE-DRILL] $m" }
Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# Логи / шляхи
$logDir = Join-Path $Root "C03"; if (!(Test-Path $logDir)){ New-Item $logDir -ItemType Directory -Force | Out-Null }
$log = Join-Path $logDir "LOG.md"; if (!(Test-Path $log)) { "# New LOG.md (init)" | Out-File -FilePath $log -Encoding UTF8 }
$archRoot = Join-Path $Root "C05\Archive"
$dayDir = (Get-ChildItem -LiteralPath $archRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName
if (-not $dayDir) { Add-Content -Path $log -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | restore-drill | FAIL | No archive days") -Encoding UTF8; Say "No archive days"; exit 1 }
$dayName = Split-Path -Leaf $dayDir

function Get-Zip([string]$dir,[string]$dname){
  $p = Join-Path $dir ("SNAPSHOT_" + $dname + ".zip")
  if (-not (Test-Path $p)) {
    $cand = Get-ChildItem -LiteralPath $dir -File -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($cand) { $p = $cand.FullName } else { $p = $null }
  }
  return $p
}

$ok=$true; $why=@()

# JSON перевірка
$json = Get-ChildItem -LiteralPath $dayDir -File -Filter "REPORT_*.json" | Select-Object -First 1
if ($json) {
  try {
    $src = if (Test-Path ($json.FullName + ".sha256")) { ((Get-Content -Raw ($json.FullName + ".sha256")).Split())[0] } else { (Get-FileHash $json.FullName -Algorithm SHA256).Hash }
    $calc = (Get-FileHash $json.FullName -Algorithm SHA256).Hash
    if ($src -ne $calc) { $ok=$false; $why += "JSON SHA256 mismatch" }
    try { $null = (Get-Content -Raw $json.FullName | ConvertFrom-Json) } catch { $ok=$false; $why += "JSON parse: $($_.Exception.Message)" }
  } catch { $ok=$false; $why += "JSON hash error: $($_.Exception.Message)" }
} else { $ok=$false; $why += "No REPORT_*.json" }

# ZIP: почекати трохи; якщо нема  запустити Auto-Archive і повторити
$zip = Get-Zip $dayDir $dayName
for($i=0; $i -lt 10 -and -not (Test-Path $zip); $i++){ Start-Sleep -Milliseconds 300; $zip = Get-Zip $dayDir $dayName }
if (-not (Test-Path $zip)) {
  try { & (Join-Path $Root 'scripts\ChechaCore-Auto-Archive.ps1') -Root $Root | Out-Null } catch {}
  Start-Sleep -Seconds 1
  $zip = Get-Zip $dayDir $dayName
}
if (-not (Test-Path $zip)) { $ok=$false; $why += "No .zip" }

# Відкриття ZIP (ZipFile.OpenRead -> COM fallback), без перевірки розміру
if ($ok -and (Test-Path $zip)) {
  $zipOk = $false
  try { $z=[IO.Compression.ZipFile]::OpenRead($zip); if ($z -and $z.Entries.Count -ge 1){ $zipOk=$true }; $z.Dispose() } catch {}
  if (-not $zipOk) {
    try { $sh=New-Object -ComObject Shell.Application; $ns=$sh.Namespace($zip); if ($ns -and $ns.Items().Count -ge 1){ $zipOk=$true } } catch {}
  }
  if (-not $zipOk) { $ok=$false; $why += "ZIP open failed (ZipFile+COM)" }
}

$state = if($ok){"OK"}else{"FAIL"}
Add-Content -Path $log -Value ("| " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | restore-drill | " + $state + " | " + ($why -join "; ")) -Encoding UTF8
Say ("State: " + $state + ($(if($why.Count -gt 0){"  "+($why -join "; ")})))
exit 0
