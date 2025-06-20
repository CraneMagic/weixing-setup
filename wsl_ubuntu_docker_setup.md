# WSL Ubuntu + Docker 环境搭建文档

## 📦 适用场景
适用于在 Windows 下使用 WSL 安装 Ubuntu，并运行轻量级、无 Docker Desktop 的 Docker 环境，支持代理和多容器项目开发。

---

## ✅ 安装步骤

### 1. 安装 WSL 和 Ubuntu
```powershell
wsl --install -d Ubuntu
```
> 推荐 Ubuntu 22.04 或 24.04

完成后打开 Ubuntu，设置用户名和密码。

---

### 2. 安装 Docker
在 Ubuntu（WSL）终端中：

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
exit  # 重启终端使用户组生效
```

---

### 3. 配置 Docker 代理（如使用 Clash/V2Ray）

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf
```

写入内容（根据实际代理端口修改）：
```ini
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1"
```

重载并重启 Docker：
```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker
```

验证：
```bash
docker info
```
应出现 HTTP Proxy/HTTPS Proxy 字段。

---

### 4. 测试功能

```bash
docker pull busybox
docker run --rm curlimages/curl -x http://127.0.0.1:7890 https://www.google.com
```

---

## 🔧 常用优化

| 目的 | 命令/建议 |
|------|-----------|
| 启用 Docker 开机启动 | `sudo systemctl enable docker` |
| 设置 bash 启动 dockerd（非 systemd）| 在 `~/.bashrc` 末尾加入 `sudo dockerd &` |
| 避免 WSL 网络掉线 | 创建 `.wslconfig` 设置 `networkingMode=mirrored`（可选）|

---

## ❌ 可选：卸载 Docker Desktop

如果你原本装过 Docker Desktop，现在已经使用原生 Docker，可以卸载：

```powershell
Stop-Service com.docker.service
```

然后在控制面板卸载 Docker Desktop。

---

## 🧪 其他建议

- 不要直接将 Docker CLI 代理配置 (`~/.docker/config.json`) 误认为 Daemon 配置
- 所有代理设置均要作用于 `dockerd` 守护进程

---

## 📁 文件清单

| 位置 | 说明 |
|------|------|
| `/etc/systemd/system/docker.service.d/http-proxy.conf` | Docker 守护进程的代理配置 |
| `~/.docker/config.json`（可选） | Docker 客户端 CLI 的代理配置 |
| `~/.bashrc`（可选） | 启动脚本、自启 dockerd |

---

## ✅ 全部完成后，你的系统将：

- 使用轻量 Ubuntu + Docker 环境
- 支持代理访问 Docker Hub
- 不再依赖 Docker Desktop
- 资源占用更低、更稳定

---

如需一键脚本部署，请查看 `setup_wsl_docker.sh` 脚本版本。

