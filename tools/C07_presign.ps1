# --- logging (auto) ---
try{
  $\__logDir = Join-Path 'C:\CHECHA_CORE' '_logs'
  New-Item -ItemType Directory -Force -Path $\__logDir | Out-Null
  $\__log = Join-Path $\__logDir ("{0}_{1:yyyy-MM-dd_HHmmss}.log" -f $MyInvocation.MyCommand.Name, (Get-Date))
  Start-Transcript -Path $\__log -Force | Out-Null
} catch { }
. "\_env.ps1"
Param(
  [Parameter(Mandatory=$true)][string]$Object,  # напр. weekly/weekly_report_2025-W34.md
  [string]$Root="C:\CHECHA_CORE",
  [string]$AliasName="c07-web",
  [string]$Bucket="c07-reports",
  [string]$Expire="24h",
  [string]$HostRewrite="http://localhost:9000"
)
$cfg = Join-Path $Root ".mc"
$std = Join-Path $env:TEMP ("presign_" + [guid]::NewGuid() + ".tmp")

$cmd = @("run","--rm","-v",("$($cfg):/root/.mc"),"minio/mc","share","download","--expire",$Expire,("$AliasName/$Bucket/$Object"))
$ps  = Start-Process -FilePath "docker" -ArgumentList $cmd -NoNewWindow -PassThru -RedirectStandardOutput $std
$ps.WaitForExit()

if(-not (Test-Path $std)){ Write-Error "Share output missing"; exit 1 }
$raw = Get-Content $std -Raw
Remove-Item $std -ErrorAction SilentlyContinue

# витягнути останній http(s) URL і відрізати службові префікси типу "URL: " чи "Share: "
$urls = ($raw -split "`r?`n" | Where-Object {$_ -match 'https?://'}) | ForEach-Object {
  [regex]::Match($_,'https?://\S+').Value
}
$link = $urls | Select-Object -Last 1
if([string]::IsNullOrWhiteSpace($link)){ Write-Error "Link not generated"; exit 1 }

# підмінити хост, якщо треба
$link = $link -replace 'http://host\.docker\.internal:9000', $HostRewrite

# у буфер
Set-Clipboard -Value $link
Write-Host "Link copied to clipboard:" -ForegroundColor Green
Write-Host $link

# надійне відкриття у дефолтному браузері
Start-Process -FilePath "$env:WINDIR\System32\cmd.exe" -ArgumentList "/c start `"$link`"" -WindowStyle Hidden | Out-Null

# --- end logging (auto) ---
try { Stop-Transcript | Out-Null } catch { }
