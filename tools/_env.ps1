$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$dockerExe = 'C:\Program Files\Docker\Docker\resources\bin\docker'
if(-not (Test-Path $dockerExe)){ throw "docker.exe not found at $dockerExe" }
$dockerDir = Split-Path -Parent $dockerExe
if(-not (($env:Path -split ';') -contains $dockerDir)){
  $env:Path = "$dockerDir;$env:Path"
}

function Ensure-Docker {
  param([int]$TimeoutSec = 120)
  # гарантуємо наявність docker.exe у PATH (залишаємо твою логіку як є)
  try { $null = & docker -v 2>$null } catch {}
  # швидка перевірка
  try {
    $null = & docker info 2>$null
    if ($LASTEXITCODE -eq 0) { return }
  } catch {}
  # старт Docker Desktop
  $dd = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
  if (Test-Path $dd) { Start-Process $dd | Out-Null }
  # очікуємо готовності
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    try {
      $null = & docker info 2>$null
      if ($LASTEXITCODE -eq 0) { break }
    } catch {}
    Start-Sleep -Seconds 3
  }
  # якщо контекст Windows  спробуємо перемкнутись на Linux
  try {
    $os = (& docker version --format "{{.Server.Os}}" 2>$null)
    if ($os -match "windows") {
      & "$env:ProgramFiles\Docker\Docker\DockerCli.exe" -SwitchLinuxEngine 2>$null
      Start-Sleep 5
      $null = & docker info 2>$null
    }
  } catch {}
  if ($LASTEXITCODE -ne 0) { throw "Docker Desktop не запущений або Linux-движок недоступний." }
}
Ensure-Docker
