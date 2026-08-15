# 私有 Docker Registry 配置说明

## 概述

本项目使用私有 Docker Registry: `registry.yijunstudio.xyz`

所有服务镜像都托管在此私有 Registry 中。

## 镜像列表

- `registry.yijunstudio.xyz/mirror/postgres:15` - PostgreSQL 数据库
- `registry.yijunstudio.xyz/weixing-websocket-server:latest` - WebSocket 服务
- `registry.yijunstudio.xyz/weixing-udp-server:latest` - UDP 数据接收服务
- `registry.yijunstudio.xyz/weixing-tcp-server:latest` - TCP 相机服务（3个实例）
- `registry.yijunstudio.xyz/weixing-service:latest` - 后端 API 服务
- `registry.yijunstudio.xyz/weixing-frontend:latest` - 前端界面
- `registry.yijunstudio.xyz/weixing-cv:latest` - 计算机视觉服务

## 登录方式

### 方法 1: 交互式登录（推荐）

```bash
docker login registry.yijunstudio.xyz
```

系统会提示输入：
- **Username**: 您的 Docker Registry 用户名
- **Password**: 您的 Docker Registry 密码

### 方法 2: 命令行登录

```bash
docker login -u <username> -p <password> registry.yijunstudio.xyz
```

### 方法 3: 使用 token（如果支持）

```bash
docker login --username=<username> --password-stdin registry.yijunstudio.xyz <<< <token>
```

## 装机脚本中的登录

在运行 `install.sh` 脚本时，会询问是否需要登录私有 Registry：

```bash
步骤 4/8: 私有 Registry 登录

是否需要登录私有 Docker Registry (registry.yijunstudio.xyz)？(y/n)
```

如果选择 `y`，脚本会提示输入凭证并尝试登录。

## 登录凭证存储

Docker 登录凭证会存储在 `~/.docker/config.json` 文件中：

```json
{
  "auths": {
    "registry.yijunstudio.xyz": {
      "auth": "base64_encoded_credentials"
    }
  }
}
```

**安全提示**：
- 该文件包含您的认证信息
- 请确保文件权限正确：`chmod 600 ~/.docker/config.json`
- 不要分享或提交此文件到版本控制

## 镜像拉取

登录成功后，即可拉取镜像：

```bash
# 拉取所有镜像
docker-compose pull

# 拉取单个镜像
docker pull registry.yijunstudio.xyz/weixing-service:latest
```

## 故障排查

### 错误: "unauthorized: authentication required"

**原因**: 未登录或凭证已过期

**解决方法**:
```bash
# 重新登录
docker login registry.yijunstudio.xyz

# 或先登出再登录
docker logout registry.yijunstudio.xyz
docker login registry.yijunstudio.xyz
```

### 错误: "no basic auth credentials"

**原因**: 凭证文件损坏或不存在

**解决方法**:
```bash
# 删除旧的凭证文件
rm ~/.docker/config.json

# 重新登录
docker login registry.yijunstudio.xyz
```

### 错误: "denied: requested access to the resource is denied"

**原因**: 用户没有权限访问该镜像

**解决方法**:
1. 确认用户名和密码正确
2. 联系管理员确认是否有访问权限
3. 确认镜像名称和标签正确

### 错误: "tls: certificate signed by unknown authority"

**原因**: Registry 的 SSL 证书不被信任

**解决方法**:
```bash
# 方法 1: 添加 Registry 到 insecure-registries（不推荐生产环境）
sudo nano /etc/docker/daemon.json

# 添加以下内容：
{
  "insecure-registries": ["registry.yijunstudio.xyz"]
}

# 重启 Docker
sudo systemctl restart docker

# 方法 2: 添加 Registry 的 CA 证书（推荐）
sudo cp your-ca.crt /etc/docker/certs.d/registry.yijunstudio.xyz/ca.crt
sudo systemctl restart docker
```

## 代理配置

如果需要通过代理访问私有 Registry：

### Docker CLI 代理

```bash
# 创建配置目录
mkdir -p ~/.docker

# 创建或编辑 config.json
cat > ~/.docker/config.json <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.example.com:8080",
      "httpsProxy": "http://proxy.example.com:8080",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
EOF
```

### Docker Daemon 代理

编辑 `/etc/docker/daemon.json`：

```json
{
  "proxies": {
    "http-proxy": "http://proxy.example.com:8080",
    "https-proxy": "http://proxy.example.com:8080",
    "no-proxy": "localhost,127.0.0.1"
  }
}
```

重启 Docker：
```bash
sudo systemctl restart docker
```

## 登出

如果需要退出登录：

```bash
docker logout registry.yijunstudio.xyz
```

## 自动化部署

### 使用 Docker Credentials Helper

对于自动化部署，可以使用 Docker Credentials Helper：

```bash
# 安装 docker-credential-pass (Linux)
sudo apt-get install docker-credential-pass

# 配置 ~/.docker/config.json
cat > ~/.docker/config.json <<EOF
{
  "credsStore": "pass"
}
EOF
```

### 使用 Kubernetes Secrets

如果在 Kubernetes 中使用，可以创建 Secret：

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.yijunstudio.xyz \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email>
```

## 最佳实践

1. **不要在脚本中硬编码密码**：使用环境变量或配置文件
2. **定期轮换密码**：建议每 3-6 个月更换一次密码
3. **使用访问令牌**：如果 Registry 支持，使用临时令牌而非长期密码
4. **限制权限**：为不同环境使用不同的账号和权限
5. **审计日志**：定期检查 Registry 的访问日志

## 获取凭证

如果您还没有访问私有 Registry 的凭证，请联系：

- **管理员**: [管理员邮箱/联系方式]
- **申请地址**: [Registry 管理平台 URL]
- **文档**: [Registry 使用文档 URL]

## 相关命令

```bash
# 查看当前登录状态
docker info | grep -A 10 "Registry Mirrors"

# 查看存储的凭证
cat ~/.docker/config.json

# 查看镜像列表
docker images | grep registry.yijunstudio.xyz

# 搜索镜像（如果 Registry 支持）
docker search registry.yijunstudio.xyz/weixing
```
