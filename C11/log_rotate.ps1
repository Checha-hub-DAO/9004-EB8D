param([string]$Path, [int]$MaxKB=512, [int]$Keep=5)
if (-not $Path) { exit 0 }
$dir = Split-Path $Path -Parent
$null = New-Item -ItemType Directory -Force -Path $dir -ErrorAction SilentlyContinue
if (-not (Test-Path $Path)) { Set-Content -Encoding utf8 -NoNewline -Path $Path -Value ''; exit 0 }
$info = Get-Item $Path
if ($info.Length -gt ($MaxKB*1KB)) {
  $name = Split-Path $Path -Leaf
  for ($i=$Keep-1; $i -ge 1; $i--) {
    $src = Join-Path $dir "$name.$i"
    $dst = Join-Path $dir "$name.$($i+1)"
    if (Test-Path $src) { Move-Item $src $dst -Force }
  }
  Move-Item $Path (Join-Path $dir "$name.1") -Force
  Set-Content -Encoding utf8 -NoNewline -Path $Path -Value ''
}
