Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$AliasName = "c07",
  [string]$Bucket = "c07-reports",
  [string]$DockerNetwork = "checha_core_default"
)
$ErrorActionPreference = "Stop"

$kpi = Join-Path $Root "C07\KPI_TRACKER.md"

# 1) Оновити щоденний рядок (джерело фіксуй як треба; зараз ставлю мітку-задачу)
& (Join-Path $Root "tools\update_daily_kpi_v11.ps1") -KpiFile $kpi -Source "C03/LOG.md:<auto>"

# 2) Опублікувати всі .md з C07 у MinIO
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools\publish_c07_v5.ps1") `
  -Root $Root -AliasName $AliasName -Bucket $Bucket -DockerNetwork $DockerNetwork
