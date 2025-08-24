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
  [string]$DockerNetwork="checha_core_default",
  [string]$PubUser="c07_pub2",
  [string]$PubPass="pjiMaKQTdCvNQpnkDgjs5Rbd"
)
$ErrorActionPreference="Stop"

function Ensure-Dir($p){ if(-not(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$cfg = Join-Path $Root ".mc"; Ensure-Dir $cfg
$pol = Join-Path $Root "policies"; Ensure-Dir $pol

# Дістаємо root-креди з контейнера MinIO (якщо не задані у сесії)
if(-not $env:MINIO_ROOT_USER -or -not $env:MINIO_ROOT_PASSWORD){
  $mn = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "minio" | % { ($_ -split ' ')[0] } | Select-Object -First 1)
  if(-not $mn){ throw "MinIO контейнер не знайдено." }
  $envs = docker inspect $mn --format '{{range .Config.Env}}{{println .}}{{end}}'
  $ROOT_USER = (($envs -split "`n" | ? { $_ -like "MINIO_ROOT_USER=*"}).Split("="))[1]
  $ROOT_PASS = (($envs -split "`n" | ? { $_ -like "MINIO_ROOT_PASSWORD=*"}).Split("="))[1]
}else{
  $ROOT_USER = $env:MINIO_ROOT_USER
  $ROOT_PASS = $env:MINIO_ROOT_PASSWORD
}

# admin alias
& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" minio/mc alias set local-admin http://minio:9000 $ROOT_USER $ROOT_PASS

# Політика для c07-reports (UTF-8 без BOM)
$policyJson = '{ "Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:CreateBucket","s3:ListBucket"],"Resource":"arn:aws:s3:::c07-reports"},{"Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:DeleteObject"],"Resource":"arn:aws:s3:::c07-reports/*"}]}'
[System.IO.File]::WriteAllText((Join-Path $pol "c07-publisher.json"), $policyJson, (New-Object System.Text.UTF8Encoding($false)))

& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" -v "$($pol):/data" minio/mc admin policy create local-admin c07-publisher /data/c07-publisher.json
& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc"                minio/mc admin user add      local-admin $PubUser $PubPass
& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc"                minio/mc admin policy attach local-admin c07-publisher --user $PubUser

# Робочі алиаси: внутрішній і зовнішній (для посилань у Windows)
& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" minio/mc alias set c07     http://minio:9000               $PubUser $PubPass
& docker run --rm                          -v "$($cfg):/root/.mc" minio/mc alias set c07-web http://host.docker.internal:9000 $PubUser $PubPass

# Бакет
& docker run --rm --network $DockerNetwork -v "$($cfg):/root/.mc" minio/mc mb --ignore-existing local-admin/c07-reports

Write-Host "Aliases ready: c07 (internal), c07-web (external)" -ForegroundColor Green

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
