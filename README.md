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

## 🔗 相关链接

- [WSL USB 设备连接](https://learn.microsoft.com/zh-cn/windows/wsl/connect-usb)
- [WSL Docker 环境搭建](wsl_ubuntu_docker_setup.md)
- [更新日志](CHANGELOG.md)
