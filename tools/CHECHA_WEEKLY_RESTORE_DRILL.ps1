param(
  [string]$Root = "C:\CHECHA_CORE"
)
$today=(Get-Date).ToString("yyyy-MM-dd")
$log  = Join-Path $Root "C03\LOG.md"
$arch = Join-Path $Root "C05\Archive"
$zip  = Get-ChildItem $arch -Recurse -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if(-not $zip){ exit 0 }
$temp = Join-Path $env:TEMP ("CHECHA_RESTORE_DRILL_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item $temp -ItemType Directory -Force | Out-Null
try{
  Expand-Archive -Path $zip.FullName -DestinationPath $temp -Force
  Add-Content $log ("| {0} | restore-drill | OK | weekly drill (ZIP={1})" -f ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")),(Split-Path $zip.FullName -Leaf))
}catch{
  Add-Content $log ("| {0} | restore-drill | FAIL | weekly drill error: {1}" -f ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")),$_.Exception.Message)
}finally{
  Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}

# SIG # Begin signature block
# MIIFiAYJKoZIhvcNAQcCoIIFeTCCBXUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEhavUbjyfra4K+atbObNOOSH
# 7gqgggMaMIIDFjCCAf6gAwIBAgIQdJVhwAGQr7pIn6GCjBUmjzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUvIe0l3f3dFHKuGQR49NqGVvDmXAwDQYJKoZI
# hvcNAQEBBQAEggEAGMZP6cBuBkh7S6LzL/lLe4j2JdFi13F2AqS8TlUVRJJWYSvo
# niV+tI+LXYFWNUHoXcSe9QNkbYRwsJ4fKvwY8CGSW5ZIFeeQ3M7mRML+Y52RB4N9
# 4GmZ8TOhWdbJu1BVOH2wDgWjMR8pTmgH+LDVuo8gT8lZgyQ4gaaqgc7WYsmA3z6/
# G5Xi+7bMjg/A6A2qFwLf9p5LaJmX8kmxTa6fK8QARvpqi219eGblZz7NkaiZh2iH
# QdXXBD99ubQyCEvJs7YmL/MTLKR7ceRj59eGEPs0EHKi/dQvMdF8ECF4XHviwCOc
# PZHfshniVUU5gbJSM6h+D0n7HcaeZhORvwMnuA==
# SIG # End signature block
