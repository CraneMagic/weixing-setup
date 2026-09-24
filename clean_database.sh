#!/bin/bash
# 每日清理 PostgreSQL 历史数据 + 磁盘上的 error 图片（均保留最近45天）
# 清理表：quality_records & measurements
# 容器名：postgres
# 数据库名：weixing-db
# 用户名：weixing
#
# error 图片为什么放在这里而不是放进 tcp-server：
# data/error/fail/ 是三个 tcp-server 容器共享的同一个目录，各自维护一份内存缓存
# 会互相误删或都以为没超限；cron 是单进程执行，天然没有这个问题。

# cron 的环境很干净，$PWD 不可靠，一律基于脚本自身位置解析
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERROR_DIR="$SCRIPT_DIR/data/error"
RETENTION_DAYS="${ERROR_IMAGE_RETENTION_DAYS:-45}"

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

# ============================
# 清理磁盘上的 error 图片（与数据库同样保留45天）
# 超过保留期的 fail 图，其 quality_records 记录已被上面的 SQL 删除，属于孤儿文件
# ============================
if [[ -d "$ERROR_DIR" ]]; then
    echo "--- 清理 error 图片: $ERROR_DIR (保留 ${RETENTION_DAYS} 天) ---"

    # 先统计再删除，便于在 cleanup.log 里回溯每次删了多少
    STALE_COUNT=$(find "$ERROR_DIR" -type f -mtime +"$RETENTION_DAYS" | wc -l)
    echo "待删除文件数: $STALE_COUNT"

    if [[ "$STALE_COUNT" -gt 0 ]]; then
        BEFORE=$(du -sh "$ERROR_DIR" 2>/dev/null | cut -f1)
        find "$ERROR_DIR" -type f -mtime +"$RETENTION_DAYS" -delete
        # 删完文件后收掉空掉的日期目录
        find "$ERROR_DIR" -mindepth 1 -type d -empty -delete
        AFTER=$(du -sh "$ERROR_DIR" 2>/dev/null | cut -f1)
        echo "error 目录占用: $BEFORE -> $AFTER"
    fi

    # 属主不一致会让 -delete 静默跳过，这里主动暴露出来
    FOREIGN=$(find "$ERROR_DIR" ! -user "$(id -un)" -print -quit 2>/dev/null)
    if [[ -n "$FOREIGN" ]]; then
        echo "警告: 存在非当前用户($(id -un))拥有的文件，可能删不掉，例如: $FOREIGN"
    fi
else
    echo "--- error 目录不存在，跳过: $ERROR_DIR ---"
fi

echo "===== Cleanup finished at $(date '+%Y-%m-%d %H:%M:%S') ====="
echo ""
