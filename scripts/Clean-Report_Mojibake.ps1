# Clean-Report_Mojibake.ps1 — removes mojibake lines from C07\REPORT.md (creates .bak)
$ErrorActionPreference = 'Stop'

$rep = 'C:\CHECHA_CORE\C07\REPORT.md'
if(-not (Test-Path $rep)){
  Write-Error "REPORT not found: $rep"
  exit 1
}

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak = "$rep.$ts.bak"
Copy-Item -LiteralPath $rep -Destination $bak -Force
Write-Host "Backup created: $bak"

# Read all lines and drop lines that contain typical mojibake sequences:
# 'рџ' (emoji bytes) or 'вЂ' (em-dash mojibake). Keeps everything else intact.
$lines = Get-Content -LiteralPath $rep -Encoding UTF8
$filtered = foreach($line in $lines){
  if($line -match 'рџ' -or $line -match 'вЂ'){ continue } else { $line }
}

# Normalize double blank lines
$normalized = @()
$prevBlank = $false
foreach($l in $filtered){
  $isBlank = [string]::IsNullOrWhiteSpace($l)
  if($isBlank -and $prevBlank){ continue }
  $normalized += $l
  $prevBlank = $isBlank
}

$normalized | Set-Content -LiteralPath $rep -Encoding UTF8
Write-Host "Cleaned REPORT.md. Original saved as: $bak"
