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


## 代码与镜像发布规范

- “构建/发布镜像”默认流程：相关测试和复核 → 只提交本次代码 → 推送 Git commit → 构建并推送双平台镜像 → 核对远端摘要和平台。不要停在仅本地构建。
- 默认平台为 `linux/amd64,linux/arm64`，只有用户明确要求才发布单平台。
- 默认镜像版本为 `YYYY.MM.DD-<12位commit>`，同时更新 `latest`；revision label 必须是已推送的完整 commit SHA。禁止 dirty 工作区发布，禁止用功能名代替 commit 版本。
- 不能把“推送镜像”说成“提交/推送代码”。最终分别报告代码 commit/推送、镜像标签/平台/推送、现场部署三个状态。
- 不得自动混入无关用户改动，不使用 `git add -A` 清理式提交；遇到无关修改应明确归属或使用干净工作区，不得删除或隐藏以绕过发布检查。
- 优先使用各仓库 `build.sh`。service、tcp-server、frontend 已加入干净工作区、远端提交与平台校验；从 Git commit 快照构建，必须让 `.dockerignore` 正常生效，不再手工 tar 排除源码。
- 复用 Buildx 缓存，不删除其他任务的构建器。镜像推送不代表现场已更新，现场部署需要单独明确授权。
- 详细流程见 `weixing-setup/docs/release-workflow.md`（从 weixing-setup 仓库内看为 `docs/release-workflow.md`）。
