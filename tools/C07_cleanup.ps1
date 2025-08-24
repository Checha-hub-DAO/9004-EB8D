#requires -Version 5.1
[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$AliasName = "c07",
  [string]$Bucket = "c07-reports",
  [string]$DockerNetwork = "checha_core_default",
  [int]$KeepDays = 30
)

. "$PSScriptRoot\_env.ps1"

$cfg      = Join-Path $Root ".mc"
$cfgMount = "$($cfg):/root/.mc"

function Invoke-Mc {
  param([string[]]$Args)
  # docker run ... minio/mc <Args>
  & $dockerExe @("run","--rm","--network",$DockerNetwork,"-v",$cfgMount,"minio/mc") + $Args
}

# 1) Видалити старі daily .txt (> KeepDays)
Invoke-Mc @("rm","--recursive","--force","--older-than",("{0}d" -f $KeepDays),"$AliasName/$Bucket/daily") | Out-Null

# 2) Проставити Content-Type для *.txt у daily/
Invoke-Mc @("find","$AliasName/$Bucket/daily","--name","*.txt","--exec",'mc cp --attr "Content-Type=text/plain; charset=utf-8" {} {}')

# 3) Проставити Content-Type для *.md по всьому бакету
Invoke-Mc @("find","$AliasName/$Bucket","--name","*.md","--exec",'mc cp --attr "Content-Type=text/markdown; charset=utf-8" {} {}')

Write-Host "Cleanup complete."