Param(
  [string]$KpiFile = "C:\CHECHA_CORE\C07\KPI_TRACKER.md",
  [datetime]$Date = (Get-Date),
  [string]$Source = ""
)

if (-not (Test-Path $KpiFile)) { Write-Host "KPI file not found: $KpiFile" -ForegroundColor Red; exit 1 }
$dateStr = $Date.ToString("yyyy-MM-dd")
$lines = Get-Content $KpiFile -Raw

if ($lines -match [regex]::Escape($dateStr)) {
  Write-Host "Row for $dateStr already exists."
  exit 0
}

# Detect DAILY KPI table header (expects Source column at the end)
$pattern = "(?s)(\| Date.*?\|\r?\n\|---.*?\|\r?\n)"
$row = "| {0} | 0 | 0 | 0 | 0 | 0 |  |  | 0 | 0 | 0 |  | {1} |\r\n" -f $dateStr, $Source
$updated = [regex]::Replace($lines, $pattern, '$1' + $row, 1)

Set-Content -Path $KpiFile -Value $updated -Encoding UTF8
Write-Host ("Appended DAILY KPI row for {0} with Source='{1}'" -f $dateStr, $Source) -ForegroundColor Green
