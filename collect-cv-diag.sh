#!/bin/bash
# cv 结果不显示 —— 现场一键诊断（只读，不改任何配置，不重启任何服务）
#
# 用法（在 weixing-setup 部署目录下运行）：
#   路由器通电时: bash collect-cv-diag.sh on
#   路由器断电时: bash collect-cv-diag.sh off
# 每次生成一个 cv-diag-<on|off>-<时间>.txt，把两个文件都发回来即可。

LABEL="${1:-unknown}"
OUT="cv-diag-${LABEL}-$(date +%Y%m%d-%H%M%S).txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEST_DIR="$SCRIPT_DIR/data/images/latest"

# 容器名默认与 weixing-setup/docker-compose.yml 一致，可用环境变量覆盖
CV="${CV_CONTAINER:-weixing-cv}"
TCPS="${TCP_CONTAINERS:-tcp-server-1 tcp-server-2 tcp-server-3}"
TCP1="${TCPS%% *}"
OTHERS="${OTHER_CONTAINERS:-backend-service websocket-server frontend}"

section() { echo; echo "===== $1 ====="; }
mtimes() { for f in "$LATEST_DIR"/*; do [ -e "$f" ] && echo "$(basename "$f") $(stat -c %y "$f" 2>/dev/null || stat -f %Sm -t %T "$f")"; done; }

{
  echo "诊断标签: $LABEL    时间: $(date '+%F %T')    主机: $(hostname)"

  section "0. 整机负载（判断电脑是否卡住：内存是否吃满、是否在大量换页、负载是否超过核数）"
  echo "CPU 核数: $(nproc 2>/dev/null)"
  uptime
  free -h 2>/dev/null
  echo "--- vmstat 每秒一次共 5 次（si/so 持续不为 0 = 在换页；wa 高 = 卡在磁盘）---"
  vmstat 1 5 2>/dev/null
  echo "--- 磁盘空间 ---"
  df -h "$SCRIPT_DIR" 2>/dev/null
  echo "--- 最近被系统 OOM 杀掉的进程 ---"
  (journalctl -k --since "-1 day" 2>/dev/null || dmesg 2>/dev/null) | grep -iE "out of memory|oom-kill|killed process" | tail -10 || true
  echo "--- 内存占用最高的 8 个进程 ---"
  ps -eo pid,rss,pcpu,comm --sort=-rss 2>/dev/null | head -9

  section "1. 容器状态与重启次数"
  docker ps -a --format '{{.Names}}\t{{.Status}}'
  for c in $CV $OTHERS $TCPS; do
    docker inspect -f '{{.Name}} restarts={{.RestartCount}} started={{.State.StartedAt}}' "$c" 2>/dev/null
  done

  section "2. 资源占用"
  docker stats --no-stream --format '{{.Name}}\tcpu={{.CPUPerc}}\tmem={{.MemUsage}}'

  section "3. cv 最近 60 秒的产出（有效直径 / 空直径）"
  CV60="$(docker logs --since 60s "$CV" 2>&1)"
  echo "发送总数:   $(echo "$CV60" | grep -c 'Data sent to WebSocket')"
  echo "有效直径:   $(echo "$CV60" | grep 'Data sent to WebSocket' | grep -vc 'D=nan')"
  echo "空直径(nan): $(echo "$CV60" | grep -c 'D=nan')"
  echo "baseline API 失败: $(echo "$CV60" | grep -c '从 API 加载 baseline 失败')"
  echo "baseline 变化重置: $(echo "$CV60" | grep -c 'Baseline updated')"
  echo "WebSocket 连接/发送失败: $(echo "$CV60" | grep -cE 'WebSocket连接失败|发送数据到WebSocket服务器失败')"
  echo "No images found: $(echo "$CV60" | grep -c 'No images found')"
  echo "--- 最近 40 行（去掉 No images found）---"
  echo "$CV60" | grep -v 'No images found' | tail -40

  section "4. cv 容器内访问 backend 的耗时（cv 每 5 秒同步调用一次，超时 5 秒）"
  docker exec -i "$CV" python - <<'PY' 2>&1
import socket, time, requests
t = time.time()
try:
    print("DNS backend-service ->", socket.gethostbyname("backend-service"), f"{time.time()-t:.3f}s")
except Exception as e:
    print("DNS 失败:", e, f"{time.time()-t:.3f}s")
for i in range(5):
    t = time.time()
    try:
        r = requests.get("http://backend-service:3000/api/parameters/computerVisionBaselineMat", timeout=5)
        print(f"第{i+1}次 status={r.status_code} 耗时={time.time()-t:.3f}s")
    except Exception as e:
        print(f"第{i+1}次 失败 耗时={time.time()-t:.3f}s {type(e).__name__}: {e}")
PY

  section "5. cv 容器内的代理环境变量（requests / websocket 都会自动使用）"
  docker exec "$CV" env 2>/dev/null | grep -i proxy || echo "无代理变量"
  docker exec "$CV" cat /etc/resolv.conf 2>/dev/null

  section "6. latest 图片是否在持续更新（间隔 3 秒看两次修改时间）"
  mtimes
  sleep 3
  echo "--- 3 秒后 ---"
  mtimes

  section "7. tcp-server 最近 60 秒的关键日志计数"
  for c in $TCPS; do
    L="$(docker logs --since 60s "$c" 2>&1)"
    echo "$c: 收到帧=$(echo "$L" | grep -c '处理队列中的JSON数据') 时间未同步=$(echo "$L" | grep -c '相机时间未同步') WS发送完成=$(echo "$L" | grep -c 'WebSocket发送完成') 清理=$(echo "$L" | grep -cE '批量删除|批量清理完成') 删除失败=$(echo "$L" | grep -c '删除失败') latest写入失败=$(echo "$L" | grep -cE '最新图片缓存失败')"
  done
  echo "--- $TCP1 最近 15 条 ERROR/WARN ---"
  docker logs --since 300s "$TCP1" 2>&1 | grep -E 'ERROR|WARN' | tail -15

  section "8. 相机时间戳样本（看是否 1970）"
  docker logs --since 30s "$TCP1" 2>&1 | grep -oE 'timestamp=[0-9]+' | tail -3
  docker logs --since 30s "$TCP1" 2>&1 | grep -oE '"timestamp":"[0-9]+"' | tail -3
} > "$OUT" 2>&1

echo "已生成: $OUT"
