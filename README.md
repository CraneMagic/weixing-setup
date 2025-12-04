# Weixing 生产环境部署

微星项目的生产环境 Docker Compose 部署配置。

## 🚀 快速开始

### 1. 环境准备

- Docker 和 Docker Compose
- 确保有足够的磁盘空间（建议至少 10GB）
- 串口设备权限（如果需要）

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑环境变量
nano .env
```

### 3. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
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

## 🔗 相关链接

- [WSL USB 设备连接](https://learn.microsoft.com/zh-cn/windows/wsl/connect-usb)
- [WSL Docker 环境搭建](wsl_ubuntu_docker_setup.md)
- [更新日志](CHANGELOG.md)
