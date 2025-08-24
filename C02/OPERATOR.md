# CHECHA_CORE — Шпаргалка оператора

## Статус / підняти
cd D:\CHECHA_CORE\docker
docker compose -f .\compose.yaml config
docker compose --profile core up -d
docker compose ps

## MinIO (mc в мережі compose)
docker run --rm --network checha_core_default 
  -e "MC_HOST_local=http://checha_admin:Checha_Strong_32char_Pass_2025!@minio:9000" 
  minio/mc ls local

## Звіт C07 (ручний запуск)
docker compose --profile reports run --rm report-generator

## Бекап c07-reports → диск, ZIP
# (скрипт: D:\CHECHA_CORE\scripts\minio_c07_backup.ps1) — тижневе завдання 03:15 Нд

## Watchdog (20:00, перевірка свіжості) + Kuma push
# (скрипт: D:\CHECHA_CORE\scripts\c07_watchdog.ps1)

## Kuma
http://localhost:3001 — монітори: MinIO API/Console, Portainer, C07 daily (Push 26h)
