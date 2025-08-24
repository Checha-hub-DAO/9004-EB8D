# c11_report_auto.ps1 (ASCII-safe)
param([string]$Root = "C:\CHECHA_CORE")

$logPath = Join-Path $Root "C03\LOG.md"
$outPath = Join-Path $Root "C07_dev\REPORT_AUTO.md"
$lines   = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 2000

$re = "\|\s*(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s*\|\s*(?<module>[^|]+)\s*\|\s*(?<status>[^|]+)\s*\|\s*(?<msg>.*)"
$events = foreach($ln in $lines) {
    if ($ln -match $re) {
        [pscustomobject]@{
            TS      = [datetime]$Matches.ts
            Module  = $Matches.module.Trim()
            Status  = $Matches.status.Trim().ToUpper()
            Msg     = $Matches.msg.Trim()
        }
    }
}

$today = Get-Date
$todayEvents = $events | Where-Object { $_.TS.Date -eq $today.Date }

$total = $todayEvents.Count
$byStatus = $todayEvents | Group-Object Status | Sort-Object Count -Descending
$byModule = $todayEvents | Group-Object Module | Sort-Object Count -Descending

New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$md = @()
$md += "# Report (auto, test) - $($today.ToString('yyyy-MM-dd'))"
$md += ""
$md += "## Totals"
$md += "Total events today: **$total**"
$md += ""
$md += "## By status"
$md += ($byStatus | ForEach-Object {"- " + $_.Name + ": " + $_.Count})
$md += ""
$md += "## By module"
$md += ($byModule | ForEach-Object {"- " + $_.Name + ": " + $_.Count})
$md += ""
$md += "## Last 10 events"
$md += ($todayEvents | Sort-Object TS -Descending | Select-Object -First 10 | ForEach-Object {
    "- [" + $_.TS.ToString('HH:mm:ss') + "][" + $_.Module + "] " + $_.Status + " - " + $_.Msg
})
$md += ""
$md += "> Auto-generated. If OK, merge into C07/REPORT.md."

$md | Set-Content -Path $outPath -Encoding UTF8

$logEntry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | c11_report_auto | OK | [AUTO] REPORT_AUTO.md updated (total=$total)"
Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

Write-Host "REPORT_AUTO.md created in C07_dev and log updated."
