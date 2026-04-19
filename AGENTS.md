# Weixing 系统架构

## 两大检测系统

系统包含两个独立的检测系统，共享同一个 WebSocket 中继和前端。

### 端面检测（测量系统）

检测管材横截面的外径、内径、壁厚、不圆度。

```
传感器 (200点×2) ──UDP──→ weixing-udp-server ──WebSocket──→ weixing-websocket-server ──→ 前端 /measurement
                              │
                              ├── 计算：样条插值→圆心拟合→射线求交→平滑→统计
                              ├── HTTP POST → weixing-service（存数据库）
                              └── HTTP POST → port 3030（原始数据上传）
```

- **数据源**：UDP 传感器，每帧 826/1441 字节
- **处理服务**：`weixing-udp-server`
- **核心代码**：`src/handler/measurement.ts`（`computeDiameters_spline` + `processDiameterData`）
- **算法文档**：`data/UDP测量计算流程.md`
- **前端页面**：`/measurement`
- **关键参数**：outerCorr、innerCorr、smoothingWindow、maxValueAdjustmentFactor、calibrationFactor

### 表面检测（视觉系统）

通过相机拍摄管材表面，AI 模型检测缺陷、测量管径。

```
相机 (3路) ──TCP──→ weixing-tcp-server ──WebSocket──→ weixing-websocket-server ──→ 前端 /quality
                        │
                        ├── 接收图像 + CV 推理结果
                        ├── 保存图像到本地/OSS
                        └── 转发到 WebSocket
                        
weixing-cv（Python）：运行 AI 模型，通过 TCP 发送推理结果给 tcp-server
```

- **数据源**：TCP 相机流（3 路，含 JPEG 图像 + 推理结果）
- **处理服务**：`weixing-tcp-server`（接收转发）+ `weixing-cv`（Python，AI 推理）
- **核心代码**：`weixing-tcp-server/src/handler/image.ts`
- **前端页面**：`/quality`
- **关键字段**：client_ip、label、confidence、pipe_diameter、image（base64）

## 共享基础设施

### weixing-websocket-server（WebSocket 中继）

所有数据的汇聚点，负责将端面和表面数据转发给前端。

- 大消息（相机帧）：`latestPerSource` 缓冲，每 80ms 均匀推送（~12fps）
- 小消息 + 测量数据（`{"rawData"` 开头）：立即 broadcast
- 背压保护：`bufferedAmount > 5MB` 时丢帧

### weixing-service（后端 API）

Express 服务，端口 3000。管理参数、存储测量数据、管材规格、校准值。

### weixing-frontend（Next.js 前端）

- `/measurement`：端面检测界面，显示外径/内径/壁厚统计 + 极坐标图
- `/quality`：表面检测界面，显示 3 路相机画面 + AI 检测结果
- `/settings`：参数配置
- `/database`、`/review`：历史数据查看

## 仓库清单

| 仓库 | 语言 | 用途 |
|---|---|---|
| `weixing-udp-server` | TypeScript | 端面检测数据处理 |
| `weixing-tcp-server` | TypeScript | 表面检测图像接收转发 |
| `weixing-cv` | Python | 表面检测 AI 模型推理 |
| `weixing-websocket-server` | TypeScript | WebSocket 消息中继 |
| `weixing-service` | TypeScript | 后端 API + 数据库 |
| `weixing-frontend` | TypeScript/Next.js | 前端界面 |
| `weixing-setup` | Shell | 装机脚本 + Claude skills |
| `weixing-python` | Python | 工具脚本 |

## 术语

| 术语 | 英文 | 含义 |
|---|---|---|
| 端面检测 | End-face measurement | UDP 传感器测量管材横截面尺寸（外径/内径/壁厚） |
| 表面检测 | Surface inspection | TCP 相机 + AI 检测管材外表面缺陷 |
| 不圆度 | Non-circularity / Out-of-roundness | 外径 max - min，衡量截面偏离圆形的程度 |
| 校准 | Calibration | 用标准样管校准传感器偏差，校准帧跳过 calibrationFactor 缩放 |
| 单值校正 | Single-value correction | `outerCorr` / `innerCorr`，对所有采样点施加相同偏移 |
| 数组校正 | Array correction | 逐点偏移数组，补偿传感器各角度的系统误差 |
| maxValueAdjustmentFactor | — | 将 max/avg 向 min 方向压缩的系数，<1 压缩，=1 不变 |
