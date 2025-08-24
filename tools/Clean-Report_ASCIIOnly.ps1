# Clean-Report_ASCIIOnly.ps1 — robust cleaner
# Removes any lines in REPORT.md that contain Cyrillic characters (common mojibake),
# creates a timestamped .bak, and normalizes encoding to UTF-8.

$ErrorActionPreference = 'Stop'
$rep = 'C:\CHECHA_CORE\C07\REPORT.md'

if(-not (Test-Path -LiteralPath $rep)){
  Write-Error "REPORT not found: $rep"
  exit 1
}

$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak = "$rep.$ts.bak"
Copy-Item -LiteralPath $rep -Destination $bak -Force
Write-Host "Backup created: $bak"

# Read and filter: drop lines containing any Cyrillic characters (Unicode category).
# This safely removes typical mojibake lines like 'рџ…', 'вЂ—', etc.
$lines = Get-Content -LiteralPath $rep -Encoding UTF8
$filtered = $lines | Where-Object { $_ -notmatch '\p{IsCyrillic}' }

# Collapse duplicate blank lines
$normalized = @()
$prevBlank = $false
foreach($l in $filtered){
  $isBlank = [string]::IsNullOrWhiteSpace($l)
  if($isBlank -and $prevBlank){ continue }
  $normalized += $l
  $prevBlank = $isBlank
}

$normalized | Set-Content -LiteralPath $rep -Encoding UTF8
Write-Host "REPORT.md cleaned (ASCII-only lines kept). Original saved as: $bak"
