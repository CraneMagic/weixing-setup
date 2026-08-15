# 装机脚本使用说明

## 快速开始

1. 将 `weixing-setup` 目录复制到目标机器的桌面
2. 打开终端，进入目录：
   ```bash
   cd ~/桌面/weixing-setup
   ```
3. 运行装机脚本：
   ```bash
   bash install.sh
   ```

## 脚本功能

脚本会自动完成以下操作：

1. **环境检查**
   - 检查 Linux 系统
   - 检查 Docker 和 Docker Compose 是否安装
   - 检查磁盘空间（建议至少 10GB）

2. **创建必要目录**
   - `data/images/` - 图片存储
   - `data/error/` - 错误图片
   - `logs/` - 日志文件
   - `temp/` - 临时文件
   - `output/` - 输出文件

3. **配置 Docker Daemon（可选）**
   - 配置镜像加速
   - 配置代理（如需要）

4. **私有 Registry 登录**
   - 登录私有 Docker Registry `registry.yijunstudio.xyz`
   - 验证凭证

5. **配置环境变量**
   - 从 `.env.example` 创建 `.env`
   - 自动设置 UID/GID
   - 自动设置 PC_NUM
   - 提示用户设置数据库密码和 OSS 密钥

6. **设置定时清理任务**
   - 每天凌晨 2:00 自动执行 `clean_database.sh`
   - 清理日志保存在 `logs/cleanup.log`

7. **拉取 Docker 镜像**
   - 拉取所有服务所需的镜像

8. **启动服务（可选）**
   - 询问是否立即启动所有服务

## 手动配置

### 环境变量

编辑 `.env` 文件，配置以下重要参数：

```bash
# 数据库密码（必须设置）
POSTGRES_PASSWORD=your_secure_password

# OSS 密钥（如果需要上传）
OSS_ACCESS_KEY_SECRET=your_secret_key

# 图片保留策略
FAIL_RETENTION_HOURS=336   # fail图片保留14天
DEFAULT_RETENTION_HOURS=24  # 其他图片保留1天
```

### 串口设备

如果需要使用串口设备，确保设备文件存在并有权限：

```bash
# 添加用户到 dialout 组
sudo usermod -aG dialout $USER

# 重新登录后生效
```

## 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 启动服务
docker-compose up -d

# 手动执行数据库清理
./clean_database.sh

# 查看定时任务
crontab -l

# 查看清理日志
tail -f logs/cleanup.log
```

## 服务访问地址

- 前端界面: http://localhost:3002
- 后端API:  http://localhost:3000
- WebSocket: ws://localhost:8080

## 故障排查

### 镜像拉取失败

如果遇到镜像拉取失败，通常是私有 Registry 认证问题：

```bash
# 重新登录私有 Registry
docker login registry.yijunstudio.xyz

# 查看登录状态
docker info | grep -A 10 "Registry"

# 清除旧的认证信息
docker logout registry.yijunstudio.xyz
rm ~/.docker/config.json
docker login registry.yijunstudio.xyz
```

详细配置请参考 [私有 Docker Registry 配置说明](PRIVATE_REGISTRY.md)。

### Docker 无法启动

```bash
# 查看 Docker 状态
sudo systemctl status docker

# 启动 Docker
sudo systemctl start docker

# 查看 Docker 日志
sudo journalctl -u docker -f
```

### 容器无法启动

```bash
# 查看容器日志
docker-compose logs [service_name]

# 查看容器状态
docker ps -a

# 重启特定服务
docker-compose restart [service_name]
```

### 权限问题

```bash
# 确保目录权限正确
sudo chown -R $USER:$USER data logs temp output
chmod -R 755 data logs temp output

# 检查串口设备权限
ls -l /dev/ttyUSB*
```

## 注意事项

1. **首次运行前**，请确保 `.env` 文件中的数据库密码和 OSS 密钥已正确配置
2. **串口设备**需要 `/dev/ttyUSB0` 和 `/dev/ttyUSB1` 可用
3. **定时清理任务**默认每天凌晨 2:00 执行，可编辑 crontab 修改
4. **建议定期备份** `data/` 目录中的数据
5. **确保有足够的磁盘空间**（建议至少 10GB）

## 更新日志

### v1.0.0 (2024)
- 初始版本
- 自动化装机流程
- 定时清理任务配置
