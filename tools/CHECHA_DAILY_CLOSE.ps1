$ErrorActionPreference = "Stop"

# --- Paths
$root   = "C:\CHECHA_CORE"
$archiveRoot = Join-Path $root "C05\Archive"
$report = Join-Path $root "C07\REPORT.md"
$log    = Join-Path $root "C03\LOG.md"
$hsPath = Join-Path $root "C07\health-summary.md"

# --- 1) Full backup (exclude C05)
$todayDate = Get-Date -Format "yyyy-MM-dd"
$todayDir  = Join-Path $archiveRoot $todayDate
New-Item $todayDir -ItemType Directory -Force | Out-Null

$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$zipPath = Join-Path $todayDir ("CHECHA_CORE_FULL_{0}.zip" -f $stamp)

$dirs  = Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -ne 'C05' }
$files = Get-ChildItem -LiteralPath $root -File
$items = @($dirs + $files)
if (-not $items -or $items.Count -eq 0) { throw "Nothing to archive in $root" }

Compress-Archive -Path ($items | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -CompressionLevel Optimal -Force

$hash = Get-FileHash $zipPath -Algorithm SHA256
$kb   = [math]::Round((Get-Item $zipPath).Length/1KB,2)

# Log backup
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content $log ("| {0} | c05-archive | OK | full backup: {1}" -f $ts, (Split-Path $zipPath -Leaf))

# --- 2) Rebuild today's events from LOG (robust parser)
$rx = '^\s*\|\s*(?<date>\d{4}-\d{2}-\d{2})\s+(?<time>\d{2}:\d{2}:\d{2})\s*\|\s*(?<mod>[^|]+?)\s*\|\s*(?<st>[^|]+?)\s*\|'
$events = @()
Get-Content $log | ForEach-Object {
  if ($_ -match $rx -and $Matches['date'] -eq $todayDate) {
    $events += [pscustomobject]@{
      Line    = $_
      Module  = $Matches['mod'].Trim()
      Status  = $Matches['st'].Trim().ToUpperInvariant()
    }
  }
}

# Aggregations
$groupMS = $events | Group-Object Module, Status | ForEach-Object {
  [pscustomobject]@{ Module=$_.Group[0].Module; Status=$_.Group[0].Status; Count=$_.Count }
} | Sort-Object Module, Status

$groupM = $events | Group-Object Module | ForEach-Object {
  [pscustomobject]@{ Module=$_.Name; Count=$_.Count }
} | Sort-Object Module

# --- 3) Write health-summary.md (events + 2 tables)
$md = @("# health-summary — Дата $todayDate","","## Події")
if ($events.Count -gt 0) { $md += '```'; $md += ($events | ForEach-Object { $_.Line }); $md += '```' } else { $md += "_Подій не знайдено._" }

$md += "","## Лічильники (Module × Status)","","| Module | Status | Count |","|---|---|---|"
if ($groupMS.Count -gt 0) { foreach($r in $groupMS){ $md += ("| {0} | {1} | {2} |" -f $r.Module,$r.Status,$r.Count) } } else { $md += "| — | — | 0 |" }

$md += "","## Модулі (усього за день)","","| Module | Count |","|---|---:|"
if ($groupM.Count -gt 0) { foreach($r in $groupM){ $md += ("| {0} | {1} |" -f $r.Module,$r.Count) } } else { $md += "| — | 0 |" }

Set-Content -Path $hsPath -Value ($md -join "`r`n") -Encoding UTF8

# --- 4) Invariant check
$totalLines = $events.Count
$sumMS      = if ($groupMS) { ($groupMS | Measure-Object Count -Sum).Sum } else { 0 }
$byStatus   = if ($events){ ($events | Group-Object Status | ForEach-Object { '{0}={1}' -f $_.Name,$_.Count }) -join ', ' } else { '—' }
$byModules  = if ($groupM){ ($groupM  | ForEach-Object { '{0}={1}' -f $_.Module,$_.Count }) -join ', ' } else { '—' }
$inv        = if ($totalLines -eq $sumMS) { 'OK' } else { "WARN (log=$totalLines vs table=$sumMS)" }

# --- 5) Retention: delete backups older than 14 days
$cutoff  = (Get-Date).AddDays(-14)
$oldZips = Get-ChildItem $archiveRoot -Recurse -Filter 'CHECHA_CORE_FULL_*.zip' | Where-Object { $_.LastWriteTime -lt $cutoff }
$deleted = 0
foreach($z in $oldZips){ try { Remove-Item $z.FullName -Force; $deleted++ } catch {} }

# --- 6) Report block
$stamp2 = Get-Date -Format "yyyy-MM-dd HH:mm"
$block = @"
### 🧹 Auto-close v1.3 — $stamp2
- Today: total=$totalLines; status=[$byStatus]; modules=[$byModules]; invariant=$inv.
- Backup: $zipPath (${kb} KB)
- SHA256: $($hash.Hash)
- Retention: deleted ZIPs — $deleted (older than 14d).
"@
Add-Content $report $block

Write-Host "✅ v1.3 done: total=$totalLines; inv=$inv; backup=$(Split-Path $zipPath -Leaf); deleted=$deleted"

# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUSjjEEIdXvi2CRYsoalT8Qkbl
# nfmgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhDSEVDSEFfQ09SRSBDb2RlIFNpZ25pbmcwHhcNMjUw
# ODE4MDgyMDQ1WhcNMjYwODE4MDg0MDQ1WjAjMSEwHwYDVQQDDBhDSEVDSEFfQ09S
# RSBDb2RlIFNpZ25pbmcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCn
# 268wSei3eEzGU2ZOcUZWesJmYdQ4yIT4J+jVN04WfrsW3JCGWJkXvWMsdoh/hKYF
# yuVSxjKLj9h8jETUrvdTbaRxYSXY6YJCgpZVQBUxEyoWhGWcm0bMsC5eyOfztyZv
# hcy+NZPJrD4nR+Px3VxZt3IBP1zwyw+ubp6HO7zPMW63ne0L/ltftk+Hk3ljSY4H
# D1XziGt6M2b4LLSHAWHrqIwrd0t59UyFUjrtRyYTlXd2aoUcPlOHsREmkLPwJDJC
# uBU7+z5+vt/AWeb0fOVUIoCyRyNXKDYwQMi/mLQV4a5DEjdp22IlwoaPeI21lQhS
# i9FV6Wf8r6976QtRkK+VAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUbg7BB+6svxNMUZRSAuLmrFWh5ckwDQYJ
# KoZIhvcNAQELBQADggEBABo+4rVCqKiS1Gns8FZchJduNcP3Gl9m3HeIb5osxvaf
# rXr0ELgHG8NyGVow1cgScW9efS0n32+USoVoUvb6SfWyMJ8F4a5Bj9cNGd7hvlfD
# zLvbqoRM5kUFvay+rNxVBsc8XmOZwg9/y7kEOYDycgSNjNM6PQZf/hmYxVLdtvQs
# WX133LbWcEOPVmUbHnHVRrFqOZHi379H0O2Cm2Rs7/ubU/Ld04wBGWnqtRBrk6MQ
# I/CsQ7I3mtoXnQlYpUiD9+IXI1A7HKs17a7CZfU67jO8GtRjXNm4BxMz+NBCkz2j
# 6NzzhoXLXl27AtcbdEA1sdsv2NrURC9Y79eQzYpiY+cxggHYMIIB1AIBATA3MCMx
# ITAfBgNVBAMMGENIRUNIQV9DT1JFIENvZGUgU2lnbmluZwIQdJVhwAGQr7pIn6GC
# jBUmjzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQU6xIUZOobVwT/hDf7N2ivrrfxPJcwDQYJKoZI
# hvcNAQEBBQAEggEAGuTuv0LhIwsITzLfNP7csfa8lChDZy0++Uh5b2x0r5LiEvpK
# JE3uEb/9IQyQ6G9musEzBtjdFf5j8Ob6p0yuw8W7dN6dihouJsVBnaI0GtkjnwPw
# pOQ1VicFlEXibVAWVJTGmobMiBb7VjleLHMwMO/sz0DE2Qufj4S8a86UisN66VoV
# N9AQ3NzYZQ2tcx30aQfXoaGkV2Ar2nrcvpmokUFb7dlwbsW8aIzb3dxvp2XBe/0n
# VBvzNEXrDs68zobZS+wXqXfMbhAGeQuH5iNA8K+cU9nU3/3cqU15Z+s6b1yrheJj
# 328c7isRtX4/f40YmWNpkJi1SwpHoxhZdN2vOQ==
# SIG # End signature block
