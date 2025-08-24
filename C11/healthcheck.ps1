param([string[]]$Names=@(
  "C11_vault_bot_daily","C11_vault_bot_weekly_zip","C11_archive_retention","C11_zip_sha_audit"
))
$logDir = "C:\CHECHA_CORE\logs"
$log    = Join-Path $logDir "healthcheck.log"
$null = New-Item -ItemType Directory -Force -Path $logDir -ErrorAction SilentlyContinue

$okCodes = 0, 267008, 267009, 267011
$namesMap = @{
  0       = "SUCCESS"
  267008  = "READY"
  267009  = "RUNNING"
  267011  = "NOT_YET_RUN"
}

$bad = @()
foreach ($n in $Names) {
  $t = Get-ScheduledTask -TaskName $n -EA SilentlyContinue
  if (-not $t) { 
    Add-Content -Encoding UTF8 $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') FAIL: $n missing"
    $bad += "$n=missing"; 
    continue 
  }
  $i = $t | Get-ScheduledTaskInfo
  $code = [int]$i.LastTaskResult
  $label = $namesMap[$code]; if (-not $label) { $label = "CODE=$code" }
  if ($okCodes -contains $code) {
    Add-Content -Encoding UTF8 $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OK:   $n $label"
  } else {
    Add-Content -Encoding UTF8 $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') FAIL: $n $label"
    $bad += "$n=$code"
  }
}

if ($bad.Count -eq 0) { Write-Output "OK"; exit 0 } else { Write-Output ("FAIL: " + ($bad -join ", ")); exit 1 }
