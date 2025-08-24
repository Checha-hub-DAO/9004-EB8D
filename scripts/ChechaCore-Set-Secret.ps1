param(
    [ValidateSet("set","show","clear")]
    [string]$Action = "set",
    [switch]$Machine
)
# Sets / shows / clears CHECHA_ZIP_PASSWORD in env (current user by default, or -Machine).
# Usage:
#   checha-set-secret                 # prompt & set for current user
#   checha-set-secret -Machine       # prompt & set for machine-wide
#   checha-set-secret show
#   checha-set-secret clear

function Write-Note($m){ Write-Host "[checha-secret] $m" }

if ($Action -eq "set") {
    $sec = Read-Host "Enter ZIP password (input hidden)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    if ($Machine) {
        setx CHECHA_ZIP_PASSWORD "$plain" /M | Out-Null
        Write-Note "Set machine env CHECHA_ZIP_PASSWORD (restart services/PowerShell to take effect)."
    } else {
        setx CHECHA_ZIP_PASSWORD "$plain" | Out-Null
        Write-Note "Set user env CHECHA_ZIP_PASSWORD."
    }
    $env:CHECHA_ZIP_PASSWORD = $plain
    Write-Note "Session variable updated too."
    exit 0
}
elseif ($Action -eq "show") {
    if ($env:CHECHA_ZIP_PASSWORD) { Write-Host ("CHECHA_ZIP_PASSWORD = " + ('*' * $env:CHECHA_ZIP_PASSWORD.Length)) }
    else { Write-Host "CHECHA_ZIP_PASSWORD is not set." }
    exit 0
}
elseif ($Action -eq "clear") {
    if ($Machine) { setx CHECHA_ZIP_PASSWORD "" /M | Out-Null } else { setx CHECHA_ZIP_PASSWORD "" | Out-Null }
    Remove-Item Env:CHECHA_ZIP_PASSWORD -ErrorAction SilentlyContinue
    Write-Note "Cleared."
    exit 0
}
