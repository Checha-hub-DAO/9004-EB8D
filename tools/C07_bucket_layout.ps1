# --- logging (auto) ---
try{
  $\__logDir = Join-Path 'C:\CHECHA_CORE' '_logs'
  New-Item -ItemType Directory -Force -Path $\__logDir | Out-Null
  $\__log = Join-Path $\__logDir ("{0}_{1:yyyy-MM-dd_HHmmss}.log" -f $MyInvocation.MyCommand.Name, (Get-Date))
  Start-Transcript -Path $\__log -Force | Out-Null
} catch { }
. "\_env.ps1"
Param(
  [string]$Root="C:\CHECHA_CORE",
  [string]$AliasName="c07",
  [string]$Bucket="c07-reports",
  [string]$DockerNetwork="checha_core_default"
)
$cfg = Join-Path $Root ".mc"

# створюємо "папки" завантаженням .keep
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/weekly/.keep"
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/daily/.keep"
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($Root)\tools:/data" minio/mc cp /data/.empty "$AliasName/$Bucket/dashboards/.keep"

# перенос відомих файлів (може вже виконаний  помилок не буде)
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" minio/mc mv "$AliasName/$Bucket/weekly_report_*.md" "$AliasName/$Bucket/weekly/" 2>$null
docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" minio/mc mv "$AliasName/$Bucket/C07_BASE_DASHBOARD.md" "$AliasName/$Bucket/dashboards/" 2>$null

Write-Host "Layout normalized (weekly/, daily/, dashboards/)" -ForegroundColor Green

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
