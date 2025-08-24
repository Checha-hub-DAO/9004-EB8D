Param([string]$Root="C:\CHECHA_CORE",[string]$AliasName="c07",[string]$Bucket="c07-reports",[string]$DockerNetwork="checha_core_default")
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "C:\CHECHA_CORE\_logs\C07_weekly_now.ps1_$ts.log"
Start-Transcript -Path $log -Force | Out-Null
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\tools\C07_weekly_now.ps1" -Root $Root -AliasName $AliasName -Bucket $Bucket -DockerNetwork $DockerNetwork
$code = $LASTEXITCODE
Stop-Transcript | Out-Null
exit ($code -as [int])