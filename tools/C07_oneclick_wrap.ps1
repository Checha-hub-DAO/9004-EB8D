Param([string]$Root="C:\CHECHA_CORE")
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "C:\CHECHA_CORE\_logs\C07_oneclick.ps1_$ts.log"
Start-Transcript -Path $log -Force | Out-Null
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\tools\C07_oneclick.ps1"
$code = $LASTEXITCODE
Stop-Transcript | Out-Null
exit ($code -as [int])