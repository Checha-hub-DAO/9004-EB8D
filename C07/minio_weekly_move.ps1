# C07 — перенос тижневих звітів у підпапку weekly (надійний спосіб)

# 1) Перегляд файлів, які будуть перенесені:
docker run --rm --network checha_core_default `
  -v "C:\CHECHA_CORE\.mc:/root/.mc" `
  minio/mc find c07/c07-reports --name "weekly_report_*.md"

# 2) Перенесення кожного знайденого файлу (через --exec):
docker run --rm --network checha_core_default `
  -v "C:\CHECHA_CORE\.mc:/root/.mc" `
  minio/mc find c07/c07-reports --name "weekly_report_*.md" --exec "mc mv {} c07/c07-reports/weekly/"

# 3) Альтернатива з --include:
docker run --rm --network checha_core_default `
  -v "C:\CHECHA_CORE\.mc:/root/.mc" `
  minio/mc mv --recursive --parents c07/c07-reports c07/c07-reports/weekly --include "weekly_report_*.md"
