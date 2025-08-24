param(
  [string]$Repo   = 'C:\CHECHA_CORE',
  [string]$Remote = 'origin',
  [string]$Branch = 'main',
  [string]$Msg    = "auto publish $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
)
$ErrorActionPreference = 'Stop'
$log = "C:\CHECHA_CORE\logs\push.log"
function Log($s){ Add-Content -Encoding UTF8 $log $s }

try {
  if (-not (Get-Command git -EA SilentlyContinue)) { Log "git not found"; exit 1 }

  # Repo існує і це git?
  git -C $Repo rev-parse --is-inside-work-tree 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { Log "not a git repo: $Repo"; exit 2 }

  # Є remote?
  git -C $Repo remote get-url $Remote 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) { Log "remote '$Remote' missing"; exit 3 }

  # Фіксуємо зміни лише якщо вони є
  git -C $Repo branch -M $Branch | Out-Null
  $changes = git -C $Repo status --porcelain
  if ($changes) {
    git -C $Repo add -A
    git -C $Repo commit -m $Msg | Out-Null
  }

  # Пуш і лог
  $pushOut = git -C $Repo push -u $Remote $Branch 2>&1
Add-Content -Encoding UTF8 $log $pushOut
if ($LASTEXITCODE -eq 0) {
  Log "OK: pushed $Branch to $Remote"
  exit 0
} else {
  Log "ERROR: git push exit=$LASTEXITCODE"
  exit 4
}
  exit 0
}
catch {
  Log "ERROR: $($_.Exception.Message)"
  exit 9
}

