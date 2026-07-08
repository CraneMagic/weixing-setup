# Weixing 工控设备监控部署指南

10 台以上工控设备的集中监控方案:每台工控通过 Grafana Alloy 主动 push 指标到 Grafana Cloud,中心统一看板。

## 架构

```
每台工控 (pc_num=01/02/.../N,通过 WiFi 出外网)
┌────────────────────────────────────────────────┐
│  Docker Compose                                │
│  ├─ 业务容器: postgres, cv, tcp-server×3, ...  │
│  ├─ pushgateway (:9091)  ← MaixCAM 相机 push  │
│  └─ alloy                                      │
│       │                                        │
│       │ 采集:                                  │
│       │  1. 主机指标 (node_exporter 内置)      │
│       │  2. 容器指标 (cadvisor 内置)           │
│       │  3. 业务指标 (tcp-server/cv /metrics)  │
│       │  4. 相机指标 (从 pushgateway 拉)       │
│       │                                        │
│       └─ 每 60 秒通过 HTTPS push (带 pc_num)   │
└──────────────────────┼─────────────────────────┘
                       │
                       ▼
              ┌────────────────────┐
              │ Grafana Cloud       │
              │  Prometheus (免费)  │
              │  Grafana UI (免费)  │
              └────────────────────┘
```

## 一次性准备:注册 Grafana Cloud

1. 访问 <https://grafana.com/auth/sign-up/create-user>,选 **Free tier** 注册
2. 登录后,左侧菜单 **My Account** → **Prometheus**(或 "Prometheus metrics" → "Send Metrics") → **Details** 页
3. 记下 3 个关键值:

   | 字段 | 示例 |
   |---|---|
   | Remote Write Endpoint | `https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push` |
   | Username / Instance ID | `1234567`(一串数字) |
   | Password / API Token | 点 **Generate now** 生成一个 token,只显示一次,妥善保存 |

## 每台工控部署步骤

### 1. 准备 `.env`

在 `weixing-setup/.env` 里补齐以下三个变量(参考 `.env.example`):

```bash
# 每台工控的唯一编号(比如 tongrang-01、tongrang-02...)
PC_NUM=tongrang-01

# 从上面 Grafana Cloud "Details" 页拷贝
GRAFANA_CLOUD_PROM_URL=https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push
GRAFANA_CLOUD_PROM_USERNAME=1234567
GRAFANA_CLOUD_PROM_PASSWORD=glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2. 启动业务 + 监控

```bash
cd /path/to/weixing-setup

# 一起启动业务和监控
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# 或者只启动监控(业务已在跑)
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d alloy pushgateway
```

### 3. 验证 alloy 采集正常

```bash
# alloy 自身的调试页面 (127.0.0.1 only,不对外)
curl http://127.0.0.1:12345/-/ready

# 看 alloy 日志,应该看到 remote_write 成功
docker logs alloy | tail -30
# 期望看到: "remote_write: ..." "component ... started"
# 不应该看到: 401 (auth 错)、connection refused (URL 错)

# 看 pushgateway 是否在收 MaixCAM 的 push
curl http://127.0.0.1:9091/metrics | grep weixing_camera
# 相机 push 后应该能看到 weixing_camera_fps 等指标
```

### 4. 在 Grafana Cloud 里查看

1. 登录 Grafana Cloud,左侧 **Explore** → 选中你的 Prometheus 数据源
2. 输入 `up{pc_num="tongrang-01"}` → 应该看到几条 series
3. 如果没有数据,检查:
   - `.env` 里三个 GRAFANA_CLOUD_* 是否填对
   - alloy 容器有没有跑起来
   - 工控能不能出外网访问 `prometheus-prod-*.grafana.net`

### 5. 导入 dashboard

1. Grafana Cloud UI → 左侧 **Dashboards** → **New** → **Import**
2. 上传 `weixing-setup/monitoring/dashboard.json`(或复制粘贴内容)
3. 选择你的 Prometheus 数据源
4. 保存后进入面板,顶部 **pc_num** 下拉筛选具体工控

## 停止监控

```bash
# 只停监控,业务继续跑
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml stop alloy pushgateway

# 完全移除监控容器和数据卷
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml rm -sf alloy pushgateway
docker volume rm weixing-setup_alloy-data weixing-setup_pushgateway-data
```

停止后,已 push 到 Grafana Cloud 的历史数据仍保留 14 天(免费版保留期)。

## MaixCAM 相机端接入(可选)

Python 相机端 (`weixing-python/main.py`) 已集成 push 逻辑,启用方式:

```bash
# 在 MaixCAM 上先装依赖
pip install prometheus_client>=0.20.0

# 启动时传入 pushgateway 地址(替换成实际工控 IP)
PUSHGATEWAY_URL=http://192.168.1.10:9091 python3 main.py
```

不设置 `PUSHGATEWAY_URL` 则不推送,零影响。

## 已暴露的指标一览

### 主机层(node_exporter 自动采集)
`node_cpu_seconds_total`、`node_memory_MemAvailable_bytes`、`node_filesystem_avail_bytes`、`node_network_receive_bytes_total` 等标准指标。

### 容器层(cadvisor 自动采集)
`container_cpu_usage_seconds_total`、`container_memory_usage_bytes`、`container_network_*`、`container_last_seen` 等。

### 业务层

| 指标 | 来源 | 标签 | 语义 |
|---|---|---|---|
| `weixing_tcp_queue_size` | tcp-server | `camera_id` | 处理队列当前长度 |
| `weixing_tcp_active_handlers` | tcp-server | `camera_id` | 当前活跃 handler 数 |
| `weixing_tcp_handler_duration_seconds` | tcp-server | `camera_id` | 单帧处理耗时(histogram) |
| `weixing_tcp_frames_total` | tcp-server | `camera_id`, `label` | 处理帧总数(pass/fail 分桶) |
| `weixing_tcp_queue_dropped_total` | tcp-server | `camera_id` | 队列满丢弃总数 |
| `weixing_tcp_ws_send_failures_total` | tcp-server | `camera_id` | WebSocket 发送失败总数 |
| `weixing_tcp_db_write_failures_total` | tcp-server | `camera_id` | 数据库写入失败总数 |
| `weixing_cv_inference_duration_seconds` | weixing-cv | — | 校准耗时 |
| `weixing_cv_baseline_load_total` | weixing-cv | `status` | baseline 加载 |
| `weixing_cv_last_calibration_timestamp` | weixing-cv | — | 最后成功校准时间戳 |
| `weixing_camera_fps` | MaixCAM | `client_ip` | 相机实时 fps |
| `weixing_frame_processing_ms` | MaixCAM | `client_ip`, `phase` | 相机端各阶段耗时 |
| `weixing_image_queue_size` | MaixCAM | `client_ip` | 相机端图像队列长度 |
| `weixing_tcp_send_failures_total` | MaixCAM | `client_ip` | 相机 TCP 发送失败 |
| `weixing_camera_info` | MaixCAM | `client_ip`, `model_type`, `model_version` | 常量,值恒 1 |

所有指标由 alloy 自动附加 `pc_num` label。

## 未来:从 Grafana Cloud 迁移到自建

当工控数量增长到 20+ 台或需要更长的保留期时,可以迁移到自建。**alloy 配置几乎不用改**,只需要在 `config.alloy` 的 `remote_write` 里加一个 endpoint 并行验证:

```river
prometheus.remote_write "grafana_cloud" {
  endpoint {
    url = sys.env("GRAFANA_CLOUD_PROM_URL")
    basic_auth {
      username = sys.env("GRAFANA_CLOUD_PROM_USERNAME")
      password = sys.env("GRAFANA_CLOUD_PROM_PASSWORD")
    }
  }
  endpoint {
    url = sys.env("SELF_HOSTED_PROM_URL")  // 新加这块
  }
}
```

自建推荐用 **VictoriaMetrics + Grafana**(比 Prometheus 内存占用低,PromQL 兼容),部署在自己的公网云主机上即可。

## 故障排查

### alloy 一直 401
`.env` 里 `GRAFANA_CLOUD_PROM_USERNAME` 或 `GRAFANA_CLOUD_PROM_PASSWORD` 错。username 应该是纯数字 instance ID,不是邮箱。

### Grafana Cloud 看不到数据
1. 先看 alloy 日志 `docker logs alloy | grep -i error`
2. 确认工控能访问外网 `curl -I https://grafana.com`
3. 手动测试 remote write:
   ```bash
   docker exec alloy wget -O- \
     --user="$GRAFANA_CLOUD_PROM_USERNAME" \
     --password="$GRAFANA_CLOUD_PROM_PASSWORD" \
     "$GRAFANA_CLOUD_PROM_URL"
   ```
   应该看到 400 或类似响应(表示能连上),而不是超时或 401。

### series 用量接近 10k 上限
Grafana Cloud UI **Usage** 页看当前 active series。可以在 `config.alloy` 里减少 `set_collectors` 采集器,或者 `disabled_metrics` 排除更多 cadvisor 指标。

### 某台工控上 alloy 起不来
```bash
docker logs alloy 2>&1 | head -50
```
常见原因:
- weixing-network 不存在 → 必须和业务 compose 一起启动
- 挂载的 `/`、`/proc`、`/sys` 权限问题 → 检查 docker daemon 是否开启了 SELinux 或 AppArmor 限制
