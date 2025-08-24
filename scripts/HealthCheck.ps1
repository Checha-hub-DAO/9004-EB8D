# HealthCheck.ps1  CHECHA (ASCII-safe)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$root  = 'C:\CHECHA_CORE'
$log   = Join-Path $root 'C03\LOG.md'
$rep   = Join-Path $root 'C07\REPORT.md'
$today = Get-Date -Format 'yyyy-MM-dd'
$nowTS = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$nowHM = Get-Date -Format 'HH:mm'

# ensure dirs
New-Item (Join-Path $root 'C03') -ItemType Directory -Force | Out-Null
New-Item (Join-Path $root 'C07') -ItemType Directory -Force | Out-Null
if(-not (Test-Path $log)) { New-Item $log -ItemType File | Out-Null }
if(-not (Test-Path $rep)) { New-Item $rep -ItemType File | Out-Null }

# tasks to audit
$tasks = @('CHECHA DayStart','CHECHA Logs Rotate')
if ($env:CHECHA_TEST_BAD) { $tasks += 'CHECHA _TestMissing_' }  # for test alerts

$alerts = @()
foreach($name in $tasks){
  try{
    $info  = Get-ScheduledTaskInfo -TaskName $name
    $state = (Get-ScheduledTask -TaskName $name).State
    $code  = $info.LastTaskResult
    if ($code -ne 0) {
      $alerts += [pscustomobject]@{
        Name    = $name
        Code    = $code
        Hex     = ('0x{0:X}' -f $code)
        LastRun = if($info.LastRunTime) { $info.LastRunTime } else { 'N/A' }
        State   = $state
      }
    }
  } catch {
    $alerts += [pscustomobject]@{
      Name=''+$name; Code='N/A'; Hex='N/A'; LastRun='N/A'; State='NotFound'
    }
  }
}

if ($alerts.Count -gt 0) {
  # 1) LOG: FAIL lines
  foreach($a in $alerts){
    Add-Content -LiteralPath $log ("| {0} | system | FAIL | scheduler: {1} last={2} ({3}) state={4}" -f $nowTS,$a.Name,$a.Code,$a.Hex,$a.State)
  }

  # 2) REPORT: ensure today's header exists (ASCII hyphen)
  $hdr = "### Day Start - $today"
  if (-not (Select-String -Path $rep -Pattern ([regex]::Escape($hdr)) -Quiet)) {
    Add-Content -Path $rep -Value $hdr -Encoding UTF8
  }

  # 3) REPORT: unique alert marker
  $marker = "### Alert $nowHM - Scheduler issues"
  if (-not (Select-String -Path $rep -Pattern ([regex]::Escape($marker)) -Quiet)) {
    $lines = $alerts | ForEach-Object {
      "- {0}: LastResult={1} ({2}), State={3}, LastRun={4}" -f $_.Name,$_.Code,$_.Hex,$_.State,$_.LastRun
    }
    ($marker + "`r`n" + ($lines -join "`r`n")) | Add-Content -Path $rep -Encoding UTF8
  }

  exit 1
} else {
  # silent OK (no noise)
  exit 0
}
