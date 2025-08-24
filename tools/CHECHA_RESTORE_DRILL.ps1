$ErrorActionPreference = "Stop"
$root   = "C:\CHECHA_CORE"
$log    = Join-Path $root "C03\LOG.md"
$report = Join-Path $root "C07\REPORT.md"

try{
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $zip = Get-ChildItem (Join-Path $root "C05\Archive") -Recurse -Filter "CHECHA_CORE_FULL_*.zip" |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $zip){ throw "No backups found" }

  $temp = Join-Path $env:TEMP "CHECHA_RESTORE_TEST"
  Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
  New-Item $temp -ItemType Directory -Force | Out-Null

  Expand-Archive -Path $zip.FullName -DestinationPath $temp -Force
  $files = Get-ChildItem $temp -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
  $sw.Stop()

  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content $log ("| {0} | restore-drill | OK | {1}; files={2}; {3} ms" -f $ts, (Split-Path $zip.FullName -Leaf), $files, $sw.ElapsedMilliseconds)

  $block = @"
### 🔄 Restore-Drill — $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- ZIP: $($zip.FullName)
- Files restored: $files
- Duration: $($sw.ElapsedMilliseconds) ms
- Status: OK
"@
  Add-Content $report $block
  Write-Host "✅ restore-drill OK: $($zip.FullName); files=$files; ms=$($sw.ElapsedMilliseconds)"
}
catch{
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content $log ("| {0} | restore-drill | FAIL | $($_.Exception.Message)" -f $ts)
  Add-Content $report ("`n### 🔄 Restore-Drill — $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n- Status: FAIL — $($_.Exception.Message)`n")
  Write-Host "❌ restore-drill FAIL: $($_.Exception.Message)"
}

# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwNd06eIo975e4lzktKCIuvrB
# mGagggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUQ5GyCIXPyHPhnfHiohgUiiFwoTMwDQYJKoZI
# hvcNAQEBBQAEggEAXg0zVxuiZk3TCrXkXfyi0UZH/zKoCVSI9Z6HBAY9oiPA4VZb
# DmPEZY5810U9KMcW5M8O0W3ItQM0Pm+WOjMNLlOvwymph2L+d6mw29jyjzDJmmkw
# LLkLZ0BUVvT4OVq2/Ds+3aCKVrQrgAaa/JsGuRmZBBinZwCAKcBwH+7VhnZ1rRBu
# vY1QAycqZJzu8VJAR6EeaMDqUFY5y807a1IiQT1n4iwMvGB0sCnhTYNapDW2wzSl
# jYHQtL7xCDD1QEJ/zw3oJ8zr7gSTPmxD36s/WLq15EqfygqDo9WimDPcso+Ld4aA
# pXZ76cmn+1QlP0/3UCir2zsxjaOdkynQ0ybINg==
# SIG # End signature block
