$ErrorActionPreference="Stop"
$tasks = "C11_vault_bot_daily","C11_vault_bot_weekly_zip","C11_archive_retention","C11_zip_sha_audit","C11_healthcheck"
foreach ($t in $tasks) {
  $xml = Get-Content "C:\CHECHA_CORE\C11\tasks\$t.xml" -Raw
  Register-ScheduledTask -TaskName $t -Xml $xml -Force
}
