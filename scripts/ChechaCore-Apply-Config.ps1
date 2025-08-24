param(
  [string]$ConfigPath = "C:\CHECHA_CORE\config\ChechaCore.config.json",
  [string]$Root = "C:\CHECHA_CORE"
)
function Write-Step([string]$m){ Write-Host "[APPLY] $m" }

# 1) Завантажити конфіг
if (!(Test-Path $ConfigPath)) { throw "Config not found: $ConfigPath" }
$cfg = Get-Content -Raw $ConfigPath | ConvertFrom-Json

# 2) Згенерувати ENV-файл для офсайту (мінімум)
$envPath = Join-Path $Root "CHECHA.env.ps1"
$offEnabled = if ($cfg.archive.offsite.enabled) { "1" } else { "0" }
$offPath    = $cfg.archive.offsite.path
$lines = @(
  '$env:CHECHA_OFFSITE_ENABLED="'+$offEnabled+'"',
  '$env:CHECHA_OFFSITE_PATH="'+$offPath+'"'
)
Set-Content -Path $envPath -Value ($lines -join "`r`n") -Encoding UTF8

# 3) Гарантувати LOG.md
$logDir = Join-Path $Root "C03"; if (!(Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
$log = Join-Path $logDir "LOG.md"; if (!(Test-Path $log)) { "# New LOG.md (init)" | Out-File -FilePath $log -Encoding UTF8 }

# 4) Лог-запис
$line = "| {0} | apply-config | offsite={1} |" -f ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")),$offPath
Add-Content -Path $log -Value $line -Encoding UTF8
Write-Step "Config applied."
