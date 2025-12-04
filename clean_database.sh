#!/bin/bash
# 每日清理 PostgreSQL 历史数据（保留最近45天）
# 清理表：quality_records & measurements
# 容器名：postgres
# 数据库名：weixing-db
# 用户名：weixing

echo "===== Cleanup started at $(date '+%Y-%m-%d %H:%M:%S') ====="

docker exec -i postgres psql -U weixing -d weixing-db <<'SQL'

-- ============================
-- 清理 quality_records （保留45天）
-- ============================
DELETE FROM public.quality_records
WHERE capture_time < now() - interval '45 days';

VACUUM (ANALYZE) public.quality_records;


-- ============================
-- 清理 measurements （保留45天）
-- ============================
DELETE FROM public.measurements
WHERE "timestamp" < now() - interval '45 days';

VACUUM (ANALYZE) public.measurements;

SQL

echo "===== Cleanup finished at $(date '+%Y-%m-%d %H:%M:%S') ====="
echo ""
