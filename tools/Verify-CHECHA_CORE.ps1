param(
    [switch]$Fix,
    [switch]$Quiet
)

$root = 'C:\CHECHA_CORE'

function Write-Info($msg){ if(-not $Quiet){ Write-Host $msg } }
function ResultRow([string]$Item,[string]$Expected,[string]$Status,[string]$Note){
    [pscustomobject]@{ Item=$Item; Expected=$Expected; Status=$Status; Note=$Note }
}

$results = @()

# 0) Root check
if(-not (Test-Path $root)){
    $results += ResultRow "Root" $root "FAIL" "Папка відсутня"
    $results | Format-Table -AutoSize
    Write-Error "Root folder not found: $root. Створи C:\CHECHA_CORE і розпакуй туди вміст архіву."
    exit 1
} else {
    $results += ResultRow "Root" $root "OK" "Знайдено"
}

# 1) Detect common mistake: nested folder (double root)
# e.g.: C:\CHECHA_CORE\CHECHA_CORE_DayStart_Starter_v1.0\C03
$nested = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object {
    Test-Path (Join-Path $_.FullName 'C03') -and
    Test-Path (Join-Path $_.FullName 'C07') -and
    Test-Path (Join-Path $_.FullName 'G43') -and
    Test-Path (Join-Path $_.FullName 'scripts')
}

if($nested){
    $folder = $nested[0].FullName
    $results += ResultRow "NestedFolder" $folder "WARN" "Вміст знаходиться усередині вкладеної папки"
    if($Fix){
        Write-Info "→ Переміщую вміст з '$folder' у '$root'..."
        Get-ChildItem -LiteralPath $folder -Force | ForEach-Object {
            $dest = Join-Path $root $_.Name
            if(Test-Path $dest){
                Write-Info "  Skip: існує '$dest'"
            } else {
                Move-Item -LiteralPath $_.FullName -Destination $dest -Force
                Write-Info "  Moved: '$($_.FullName)' → '$dest'"
            }
        }
        # Спробуємо видалити порожню вкладену папку
        try { Remove-Item -LiteralPath $folder -Force -Recurse -ErrorAction SilentlyContinue } catch {}
    } else {
        Write-Info "⚠ Виявлено вкладену папку. Запусти з параметром -Fix, щоб перемістити вміст нагору."
    }
} else {
    $results += ResultRow "NestedFolder" "(не очікується)" "OK" "Немає вкладеної оболонки"
}

# 2) Expected dirs
$dirs = @(
    'C03',
    'C07',
    'G43\topics',
    'scripts'
)
foreach($d in $dirs){
    $p = Join-Path $root $d
    if(Test-Path $p){ $results += ResultRow "Dir" $p "OK" "Знайдено" }
    else { $results += ResultRow "Dir" $p "FAIL" "Відсутня" }
}

# 3) Expected files
$files = @(
    'C03\LOG.md',
    'C07\REPORT.md',
    'C07\health-summary.md',
    'C07\KPI_TRACKER.md',
    'G43\topics\ITETA_Topic_003.md',
    'scripts\DayStart.ps1'
)
foreach($f in $files){
    $p = Join-Path $root $f
    if(Test-Path $p){ $results += ResultRow "File" $p "OK" "Знайдено" }
    else { $results += ResultRow "File" $p "FAIL" "Відсутній" }
}

# 4) Sanity checks (lightweight)
$repPath = Join-Path $root 'C07\REPORT.md'
if(Test-Path $repPath){
    $rep = Get-Content $repPath -Raw -ErrorAction SilentlyContinue
    if($rep -match '###\s+🌅\s*Day Start'){ $results += ResultRow "REPORT.md" "Містить Day Start" "OK" "Заголовок знайдено" }
    else { $results += ResultRow "REPORT.md" "Містить Day Start" "WARN" "Заголовок не знайдено (не критично)" }
}

$hsPath = Join-Path $root 'C07\health-summary.md'
if(Test-Path $hsPath){
    $hs = Get-Content $hsPath -Raw -ErrorAction SilentlyContinue
    if($hs -match '#\s*health-summary'){ $results += ResultRow "health-summary.md" "Є заголовок" "OK" "Виглядає коректно" }
}

# 5) Output
$ok = ($results | Where-Object { $_.Status -eq 'OK' }).Count
$warn = ($results | Where-Object { $_.Status -eq 'WARN' }).Count
$fail = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count

if(-not $Quiet){ $results | Format-Table -AutoSize }

Write-Host ""
Write-Host "--- SUMMARY ---"
Write-Host "OK=$ok  WARN=$warn  FAIL=$fail"

if($fail -eq 0){
    Write-Host ""
    Write-Host "✅ Структура придатна. Можна запускати:"
    Write-Host "   PowerShell (адмін) → C:\CHECHA_CORE\scripts\DayStart.ps1"
} else {
    Write-Host ""
    Write-Host "⚠ Є помилки. Виправи вручну або запусти:"
    Write-Host "   PowerShell (адмін) → .\Verify-CHECHA_CORE.ps1 -Fix"
}

exit ([int]([bool]($fail -gt 0)))
