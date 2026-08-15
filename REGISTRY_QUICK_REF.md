# 私有 Docker Registry 快速参考

## Registry 信息

```
地址: registry.yijunstudio.xyz
类型: 私有 Registry
认证: 需要
```

## 快速登录

```bash
docker login registry.yijunstudio.xyz
```

## 镜像列表

| 服务 | 镜像 | 标签 |
|------|------|------|
| PostgreSQL | registry.yijunstudio.xyz/mirror/postgres | 15 |
| WebSocket | registry.yijunstudio.xyz/weixing-websocket-server | latest |
| UDP Server | registry.yijunstudio.xyz/weixing-udp-server | latest |
| TCP Server (×3) | registry.yijunstudio.xyz/weixing-tcp-server | latest |
| Backend | registry.yijunstudio.xyz/weixing-service | latest |
| Frontend | registry.yijunstudio.xyz/weixing-frontend | latest |
| CV Service | registry.yijunstudio.xyz/weixing-cv | latest |

## 常见错误速查

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `unauthorized: authentication required` | 未登录或凭证过期 | `docker login registry.yijunstudio.xyz` |
| `no basic auth credentials` | 凭证文件损坏 | `rm ~/.docker/config.json && docker login ...` |
| `denied: requested access to the resource is denied` | 权限不足 | 联系管理员或确认凭证 |
| `tls: certificate signed by unknown authority` | 证书不被信任 | 添加 CA 证书或使用 insecure-registries |

## 常用命令

```bash
# 登录
docker login registry.yijunstudio.xyz

# 登出
docker logout registry.yijunstudio.xyz

# 拉取所有镜像
docker-compose pull

# 拉取单个镜像
docker pull registry.yijunstudio.xyz/weixing-service:latest

# 查看已拉取的镜像
docker images | grep registry.yijunstudio.xyz

# 查看登录凭证
cat ~/.docker/config.json
```

## 获取凭证

请联系管理员获取 Registry 访问凭证。

## 详细文档

详见 [PRIVATE_REGISTRY.md](PRIVATE_REGISTRY.md)
