param(
    [string]$Root = "D:\CHECHA_CORE",
    [string]$Subject,
    [string]$Body,
    [ValidateSet("INFO","WARN","FAIL","OK")]
    [string]$Severity = "INFO"
)

function Write-Step($m){ Write-Host ("[NOTIFY] " + $m) }

# Load ENV
$envFile = Join-Path $Root "CHECHA.env.ps1"
if (Test-Path $envFile) { . $envFile }

# Telegram (token only from ENV)
$tgEnabled = ($env:CHECHA_TG_ENABLED -eq "1")
$tgToken   = $env:CHECHA_TG_TOKEN
$tgChat    = $env:CHECHA_TG_CHAT

# Email (password only from ENV)
$mailEnabled = ($env:CHECHA_MAIL_ENABLED -eq "1")
$mailSmtp = $env:CHECHA_MAIL_SMTP
$mailPort = [int]($env:CHECHA_MAIL_PORT)
$mailFrom = $env:CHECHA_MAIL_FROM
$mailTo   = $env:CHECHA_MAIL_TO
$mailUser = $env:CHECHA_MAIL_USER
$mailPass = $env:CHECHA_MAIL_PASS
$mailTls  = ($env:CHECHA_MAIL_TLS -eq "1")

$msg = "[{0}] {1}`n{2}" -f $Severity, $Subject, $Body

# Telegram
if ($tgEnabled -and $tgToken -and $tgChat) {
    try {
        $url = "https://api.telegram.org/bot$tgToken/sendMessage"
        $payload = @{ chat_id = $tgChat; text = $msg }
        Invoke-RestMethod -Method Post -Uri $url -Body $payload -ErrorAction Stop | Out-Null
        Write-Step "Telegram sent."
    } catch {
        Write-Step ("Telegram failed: " + $_.Exception.Message)
    }
}

# Email
if ($mailEnabled -and $mailSmtp -and $mailFrom -and $mailTo) {
    try {
        $secure = $null
        if ($mailUser -and $mailPass) {
            $secure = ConvertTo-SecureString $mailPass -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential ($mailUser, $secure)
        } else {
            $cred = $null
        }
        Send-MailMessage -SmtpServer $mailSmtp -Port $mailPort -UseSsl:$mailTls -To $mailTo -From $mailFrom -Subject $Subject -Body $msg -Credential $cred -ErrorAction Stop
        Write-Step "Email sent."
    } catch {
        Write-Step ("Email failed: " + $_.Exception.Message)
    }
}
