# Weixing 生产环境部署

微星项目的生产环境 Docker Compose 部署配置。

## 🚀 快速开始

### 1. 环境准备

- Docker 和 Docker Compose
- 私有 Docker Registry 访问权限（见 [PRIVATE_REGISTRY.md](PRIVATE_REGISTRY.md)）
- 确保有足够的磁盘空间（建议至少 10GB）
- 串口设备权限（如果需要）

### 2. 登录私有 Registry

```bash
docker login registry.yijunstudio.xyz
```

输入您的用户名和密码。详见 [私有 Docker Registry 配置说明](PRIVATE_REGISTRY.md)。

### 3. 配置 Docker Daemon（可选）

如果需要通过代理访问互联网（如下载 Docker 镜像），可以配置 Docker Daemon 代理：

#### Linux 系统配置步骤

```bash
# 1. 复制 daemon.json 到 Docker 配置目录
sudo cp /home/tongrang/桌面/weixing-setup/daemon.json /etc/docker/daemon.json

# 2. 编辑代理地址（根据实际代理地址修改）
sudo nano /etc/docker/daemon.json

# 3. 重启 Docker 服务使配置生效
sudo systemctl restart docker

# 4. 验证配置是否生效
sudo docker info | grep -i proxy
```

#### Windows 系统配置步骤

```powershell
# 1. 复制 daemon.json 到 Docker 配置目录
# 位置: %programdata%\docker\config\daemon.json
# 或使用 Docker Desktop 设置界面配置代理

# 2. 重启 Docker Desktop 应用
```

**注意**：
- 请根据实际代理地址修改 `daemon.json` 中的 `http-proxy` 和 `https-proxy` 值
- 如果不需要代理，可以跳过此步骤
- 配置文件位置：
  - Linux: `/etc/docker/daemon.json`
  - Windows: `%programdata%\docker\config\daemon.json`

### 4. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑环境变量
nano .env
```

### 单独指定镜像版本

`.env` 的 `TAG` 仍是业务镜像的统一默认值。可复制本机版本模板，分别固定各服务：

```bash
cp .env.local.example .env.local
nano .env.local
```

```dotenv
SERVICE_TAG=2026.11.14-xxxxxxxxxxxx
FRONTEND_TAG=2026.11.14-yyyyyyyyyyyy
TCP_SERVER_TAG=2026.11.14-zzzzzzzzzzzz
```

可用变量：`WEBSOCKET_TAG`、`UDP_TAG`、`TCP_SERVER_TAG`（三路共用）、`SERVICE_TAG`、`FRONTEND_TAG`、`CV_TAG`。未设置或留空时回退到 `TAG`，最后回退到 `latest`。`HEARTBEAT_TAG` 独立配置，默认 `latest`。标签必须对应各仓库已发布的实际版本。

```bash
./compose.sh config --images  # 检查最终版本，不启动容器
./compose.sh pull
./compose.sh up -d
```

`compose.sh` 使用 Docker Compose V2（支持多个 `--env-file`），依次读取 `.env` 和可选的 `.env.local`，后者覆盖前者；shell 中已导出的同名变量优先级最高。`.env.local` 不提交 Git。直接运行 `docker compose` 不会自动读取 `.env.local`；也可把上述变量直接写入 `.env`。`install.sh` 的拉取和启动步骤使用同一入口。原有 `.env` 中的 `COMPOSE_FILE` 内存档位配置继续生效。

**后端服务 URL 配置**：`WEIXING_SERVICE_BASE_URL` 为后端服务基础地址，udp-server 等由此拼接 `/api/parameters`、`/api/measurements`、`/api/relay` 等路径。Docker 部署时通常为 `http://backend-service:3000`。

### 导出当前设备镜像版本

在当前设备的 setup 目录运行（需要 Bash 和 Docker 访问权限）：

```bash
./export-current-env.sh
```

生成 `.env.current`，复制到另一台设备的 setup 目录并命名为 `.env.local`，然后使用 `./compose.sh config --images` 检查，再执行 `./compose.sh pull` 和 `./compose.sh up -d`。也可用 `--output 路径` 指定输出位置。

脚本读取正在运行的容器及其实际镜像摘要，导出 `latest@sha256:...`，确保目标设备拉取相同镜像。摘要对应当前平台，因此此文件用于相同平台的设备（例如均为 `linux/amd64`）。全部七类服务必须运行，三路 TCP 必须使用同一镜像，且本地镜像必须有配置仓库的 RepoDigest；否则报错并保留旧文件。文件仅包含镜像版本，不包含密码、网络或设备配置，也不自动修改目标设备或重启服务。

### 设备看板心跳（weixing-heartbeat）

`weixing-heartbeat` 每 60 秒把本机主机信息、各容器状态与镜像版本上报到远端，在 reviewer 前端「设备」页面查看。需要在 `.env` 中填写：

```bash
FLEET_API_URL=https://weixing-measurement-service-configuration.dev.yijunstudio.xyz
FLEET_TOKEN=<向管理员索取>
```

未填写时该容器保持运行但空转，只输出一条错误日志，不影响其它业务容器；填写 `FLEET_API_URL` / `FLEET_TOKEN` 后执行 `docker compose up -d weixing-heartbeat` 即可生效。

每台机器的 `PC_NUM` 必须唯一，否则多台机器会被合并成同一台设备。

上线顺序：必须先把 heartbeat 镜像推送到镜像仓库，再让现场拉取本次 compose 变更，否则 `docker compose up` 会因拉取不到该镜像而失败。镜像标签由 `HEARTBEAT_TAG`（默认 `latest`）控制，独立于业务 `TAG`。

### 5. 快速安装（推荐）

使用自动化装机脚本：

```bash
# 复制 weixing-setup 到目标机器桌面后
cd ~/桌面/weixing-setup
bash install.sh
```

脚本会自动完成环境检查、目录创建、Registry 登录、镜像拉取等所有配置步骤。

详见 [装机脚本使用说明](INSTALL.md)。

### 6. 手动启动服务（如果不使用装机脚本）

```bash
# 启动所有服务
./compose.sh up -d

# 查看服务状态
./compose.sh ps

# 查看日志
./compose.sh logs -f
```

## 📁 目录结构

```
weixing-setup/
├── data/                    # 数据目录
│   ├── images/              # 正常图片
│   └── error/               # 错误图片
├── logs/                    # 日志目录
├── temp/                    # 临时文件
├── docker-compose.yml       # Docker配置
├── .env                     # 环境变量
├── clean_database.sh        # 数据库清理脚本
└── CHANGELOG.md             # 更新日志
```

## 🔧 服务说明

| 服务            | 端口 | 说明           |
| --------------- | ---- | -------------- |
| PostgreSQL      | 5432 | 数据库服务     |
| Backend Service | 3000 | 后端 API 服务  |
| Frontend        | 3002 | 前端界面       |
| WebSocket       | 8080 | WebSocket 服务 |
| UDP Server      | 2000 | UDP 数据接收   |
| TCP Server 1    | 8999 | TCP 相机服务 1 |
| TCP Server 2    | 9000 | TCP 相机服务 2 |
| TCP Server 3    | 9001 | TCP 相机服务 3 |

## 📝 重要说明

- 所有图片数据统一存储在 `data/` 目录下
- 错误图片存储在 `data/error/` 子目录
- 日志文件存储在 `logs/` 目录
- 确保 `data/` 目录有足够的存储空间

## 🗄️ 数据库维护

### 自动清理历史数据

项目提供了数据库清理脚本 `clean_database.sh`，用于定期清理历史数据（保留最近 45 天）。

#### 手动执行清理

```bash
# 执行清理脚本
./clean_database.sh
```

#### 设置定时任务（推荐）

建议设置每日自动执行清理任务，避免数据库数据过多：

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每天凌晨2点执行）
0 2 * * * /home/tongrang/桌面/weixing-setup/clean_database.sh >> /home/tongrang/桌面/weixing-setup/logs/cleanup.log 2>&1
```

**注意**：请将路径替换为实际的项目路径。

#### 清理说明

- **清理表**：`quality_records` 和 `measurements`
- **保留期限**：最近 45 天的数据
- **清理后操作**：自动执行 `VACUUM ANALYZE` 优化表性能

### 查看数据库表大小

可以使用以下 SQL 查询查看各个表的大小（按总大小降序排列）：

```sql
SELECT
    relname AS table,
    pg_size_pretty(pg_total_relation_size(relid)) AS total
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

**执行方式**：

```bash
# 通过 Docker 容器执行查询
docker exec -i postgres psql -U weixing -d weixing-db -c "SELECT relname AS table, pg_size_pretty(pg_total_relation_size(relid)) AS total FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;"
```

## 🔗 相关链接

- [WSL USB 设备连接](https://learn.microsoft.com/zh-cn/windows/wsl/connect-usb)
- [WSL Docker 环境搭建](wsl_ubuntu_docker_setup.md)
- [更新日志](CHANGELOG.md)
