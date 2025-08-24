Param(
  [string]$LinksFile="C:\CHECHA_CORE\C07\_links\latest.txt"
)
if(!(Test-Path $LinksFile)){ Write-Host "No latest.txt" -ForegroundColor Yellow; exit 0 }
(Get-Content $LinksFile) | ForEach-Object {
  if ($_ -match '^\w+:\s+(https?://\S+)$') {
    $u = $Matches[1]
    # безпечний запуск з лапками, щоб & не ламав PS
    Start-Process -FilePath "$env:WINDIR\System32\cmd.exe" -ArgumentList "/c start `"$u`""
  }
}