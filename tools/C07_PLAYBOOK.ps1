#requires -Version 5.1
[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$Alias = "c07",
  [string]$Bucket = "c07-reports",
  [string]$DockerNetwork = "checha_core_default",
  [switch]$RunNow,
  [switch]$SetupTasks
)

$ErrorActionPreference = 'Stop'
$tools = Join-Path $Root 'tools'

function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

. "$tools\_env.ps1"

$req = @(
  "$tools\C07_weekly_now.ps1",
  "$tools\C07_oneclick.ps1",
  "$tools\C07_cleanup.ps1",
  "$tools\C07_daily_kpi_task.ps1"
)
$missing = $req | Where-Object { -not (Test-Path $_) }
if($missing){ Fail ("Missing scripts:`n - " + ($missing -join "`n - ")) }

if($RunNow){
  Ok "Weekly -> publish"
  & "$tools\C07_weekly_now.ps1" -Root $Root -AliasName $Alias -Bucket $Bucket -DockerNetwork $DockerNetwork

  Ok "Oneclick -> presign links"
  & "$tools\C07_oneclick.ps1"

  Ok "Cleanup"
  & "$tools\C07_cleanup.ps1" -Root $Root -AliasName $Alias -Bucket $Bucket -DockerNetwork $DockerNetwork
}

function Ensure-Task {
  param(
    [string]$Name,
    [string]$ScriptPath,
    [Microsoft.Management.Infrastructure.CimInstance]$Trigger
  )
  $act = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
  $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
  if(Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue){
    Set-ScheduledTask -TaskName $Name -Action $act -Trigger $Trigger -Settings $set | Out-Null
  } else {
    Register-ScheduledTask -TaskName $Name -Action $act -Trigger $Trigger -Settings $set | Out-Null
  }
  Ok "Task ensured: $Name"
}

if($SetupTasks){
  $t1 = New-ScheduledTaskTrigger -Daily -At 21:00
  Ensure-Task -Name "C07_DailyKPI_and_Publish" -ScriptPath "$tools\C07_daily_kpi_task.ps1" -Trigger $t1

  $t2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 21:05
  Ensure-Task -Name "C07_WeeklyReport_and_Publish" -ScriptPath "$tools\C07_weekly_now.ps1" -Trigger $t2

  $t3 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 21:06
  Ensure-Task -Name "C07_Weekly_Presign" -ScriptPath "$tools\C07_oneclick.ps1" -Trigger $t3

  $t4 = New-ScheduledTaskTrigger -Daily -At 03:15
  Ensure-Task -Name "C07_Daily_Cleanup" -ScriptPath "$tools\C07_cleanup.ps1" -Trigger $t4
}

$report = Get-ScheduledTask -TaskName 'C07_*' | ForEach-Object {
  $info = $_ | Get-ScheduledTaskInfo
  [PSCustomObject]@{
    Task    = $_.TaskName
    State   = $_.State
    LastRun = $info.LastRunTime
    NextRun = $info.NextRunTime
    Result  = $info.LastTaskResult
  }
}
"`n=== Scheduled Tasks Summary ==="
$report | Format-Table -Auto

$linksFile = Join-Path $Root 'C07\_links\latest.txt'
if(Test-Path $linksFile){ Ok "Latest links: $linksFile" } else { Warn "Links file not found yet; run oneclick once." }
Ok "Playbook complete."