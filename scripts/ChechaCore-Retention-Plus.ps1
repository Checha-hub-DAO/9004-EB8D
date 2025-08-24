param(
    [Parameter(Mandatory=$false)]
    [string]$Root = "D:\CHECHA_CORE",

    # Separate policies for folders and ZIPs
    [int]$KeepDailyDays_Folders = 60,
    [int]$KeepDailyDays_Zips    = 90,

    [int]$KeepWeeklyWeeks_Folders = 26,
    [int]$KeepWeeklyWeeks_Zips    = 26,

    [int]$KeepMonthlyMonths_Folders = 24,
    [int]$KeepMonthlyMonths_Zips    = 36,

    [switch]$DryRun
)

function Write-Step($msg) { Write-Host ("[RETENTION+] " + $msg) }

$archiveRoot = Join-Path $Root "C05\Archive"
if (-not (Test-Path $archiveRoot)) { Write-Error "Archive root not found: $archiveRoot"; exit 1 }

$today = Get-Date
$dates = Get-ChildItem -LiteralPath $archiveRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
    Sort-Object Name

if ($dates.Count -eq 0) { Write-Step "No dated archive folders found."; exit 0 }

function Build-KeepSet {
    param([int]$keepDaily, [int]$keepWeekly, [int]$keepMonthly)
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($i=0; $i -lt $keepDaily; $i++) { [void]$set.Add($today.AddDays(-$i).ToString("yyyy-MM-dd")) }
    $weeks = 0; $cursor = $today
    while ($weeks -lt $keepWeekly) {
        if ($cursor.DayOfWeek -eq 'Sunday') { [void]$set.Add($cursor.ToString("yyyy-MM-dd")); $weeks++ }
        $cursor = $cursor.AddDays(-1)
    }
    for ($m=0; $m -lt $keepMonthly; $m++) {
        $first = (Get-Date -Year $today.Year -Month $today.Month -Day 1).AddMonths(-$m)
        [void]$set.Add($first.ToString("yyyy-MM-dd"))
    }
    return $set
}

$keepFolders = Build-KeepSet -keepDaily $KeepDailyDays_Folders -keepWeekly $KeepWeeklyWeeks_Folders -keepMonthly $KeepMonthlyMonths_Folders
$keepZips    = Build-KeepSet -keepDaily $KeepDailyDays_Zips    -keepWeekly $KeepWeeklyWeeks_Zips    -keepMonthly $KeepMonthlyMonths_Zips

$deleteFolders = @()
$deleteZips = @()
$deleteSidecars = @()

foreach ($d in $dates) {
    $name = $d.Name
    if (-not $keepFolders.Contains($name)) {
        $snapFolders = Get-ChildItem -LiteralPath $d.FullName -Directory -Filter "SNAPSHOT_*" -ErrorAction SilentlyContinue
        foreach ($sf in $snapFolders) { $deleteFolders += $sf }
    }
    if (-not $keepZips.Contains($name)) {
        $zips = Get-ChildItem -LiteralPath $d.FullName -File -Filter "*.zip" -ErrorAction SilentlyContinue
        foreach ($z in $zips) {
            $deleteZips += $z
            $sha = $z.FullName + ".sha256"
            if (Test-Path $sha) { $deleteSidecars += (Get-Item -LiteralPath $sha) }
        }
    }
}

Write-Step ("Candidates — Folders: {0}, ZIPs: {1}, SHA256: {2}" -f $deleteFolders.Count, $deleteZips.Count, $deleteSidecars.Count)

if ($DryRun) {
    foreach ($x in $deleteFolders) { Write-Host ("FOLDER -> " + $x.FullName) }
    foreach ($x in $deleteZips) { Write-Host ("ZIP    -> " + $x.FullName) }
    foreach ($x in $deleteSidecars) { Write-Host ("SHA256 -> " + $x.FullName) }
    Write-Step "Dry run — no deletions."
    exit 0
}

foreach ($x in $deleteFolders) {
    try { Remove-Item -LiteralPath $x.FullName -Recurse -Force -ErrorAction Stop; Write-Step ("Deleted folder: " + $x.FullName) }
    catch { Write-Host ("Failed folder: " + $x.FullName + " — " + $_.Exception.Message) }
}
foreach ($x in $deleteZips) {
    try { Remove-Item -LiteralPath $x.FullName -Force -ErrorAction Stop; Write-Step ("Deleted zip: " + $x.FullName) }
    catch { Write-Host ("Failed zip: " + $x.FullName + " — " + $_.Exception.Message) }
}
foreach ($x in $deleteSidecars) {
    try { Remove-Item -LiteralPath $x.FullName -Force -ErrorAction Stop; Write-Step ("Deleted sha256: " + $x.FullName) }
    catch { Write-Host ("Failed sha256: " + $x.FullName + " — " + $_.Exception.Message) }
}


# Offsite retention (if enabled)
$offEnabled = ($env:CHECHA_OFFSITE_ENABLED -eq "1"); $offPath = $env:CHECHA_OFFSITE_PATH
if ($offEnabled -and $offPath -and (Test-Path $offPath)) {
    $offDates = Get-ChildItem -LiteralPath $offPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name
    $deleteOff = @()
    foreach ($d in $offDates) {
        $name = $d.Name
        if (-not $keepZips.Contains($name)) { $deleteOff += $d }
    }
    Write-Step ("Offsite candidates — Days={0}" -f $deleteOff.Count)
    if ($DryRun) {
        foreach ($x in $deleteOff) { Write-Host ("OFFSITE -> " + $x.FullName) }
    } else {
        foreach ($x in $deleteOff) {
            try { Remove-Item -LiteralPath $x.FullName -Recurse -Force -ErrorAction Stop; Write-Step ("Deleted offsite: " + $x.FullName) }
            catch { Write-Host ("Failed offsite: " + $x.FullName + " — " + $_.Exception.Message) }
        }
    }
}

# Log
$logPath = Join-Path $Root "C03\LOG.md"
$line = "| {0} | retention+ | deleted-folders={1}; deleted-zips={2}; deleted-sha256={3} |" -f ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")), $deleteFolders.Count, $deleteZips.Count, $deleteSidecars.Count
Add-Content -Path $logPath -Value $line -Encoding UTF8

exit 0
