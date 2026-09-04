#!/bin/bash
# Weixing 装机脚本
# 用途：在复制 weixing-setup 到目标机器桌面后，自动完成初始化配置
# 使用方法：bash install.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log_info "================================================"
log_info "Weixing 装机脚本启动"
log_info "当前目录: $SCRIPT_DIR"
log_info "================================================"
echo ""

log_info "步骤 1/8: 检查系统环境"

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "此脚本仅支持 Linux 系统"
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    log_warn "不建议以 root 用户运行此脚本"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
fi
log_info "✓ Docker 已安装: $(docker --version | cut -d' ' -f3 | tr -d ',')"

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi
log_info "✓ Docker Compose 已安装: $(docker-compose --version | cut -d' ' -f4 | tr -d ',')"

AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | tr -d 'G')
if [[ $AVAILABLE_SPACE -lt 10 ]]; then
    log_warn "可用磁盘空间不足 10GB（当前: ${AVAILABLE_SPACE}GB），建议释放空间"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
log_info "✓ 可用磁盘空间: ${AVAILABLE_SPACE}GB"

echo ""

log_info "步骤 2/8: 创建必要目录"

mkdir -p data/images data/error logs temp output
chmod -R 755 data logs temp output
log_info "✓ 目录创建完成: data/, logs/, temp/, output/"

echo ""

log_info "步骤 3/8: 配置 Docker Daemon"

if [[ -f "daemon.json" ]]; then
    read -p "是否配置 Docker 代理和镜像加速？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ ! -f "/etc/docker/daemon.json" ]] || ! grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
            log_info "复制 daemon.json 到 /etc/docker/daemon.json"
            sudo cp daemon.json /etc/docker/daemon.json

            if grep -q '"proxies": {}' /etc/docker/daemon.json; then
                log_warn "daemon.json 中代理配置为空，如需代理请手动编辑 /etc/docker/daemon.json"
            fi

            log_info "重启 Docker 服务..."
            sudo systemctl restart docker
            log_info "✓ Docker 配置完成"
        else
            log_info "Docker 配置已存在，跳过"
        fi
    else
        log_info "跳过 Docker 配置"
    fi
else
    log_warn "daemon.json 不存在，跳过 Docker 配置"
fi

echo ""

log_info "步骤 4/8: 私有 Registry 登录"

PRIVATE_REGISTRY="registry.yijunstudio.xyz"
read -p "是否需要登录私有 Docker Registry ($PRIVATE_REGISTRY)？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "登录私有 Docker Registry: $PRIVATE_REGISTRY"
    echo "请输入您的 Docker Registry 凭证"
    if docker login "$PRIVATE_REGISTRY"; then
        log_info "✓ 私有 Registry 登录成功"
    else
        log_error "私有 Registry 登录失败，请检查用户名和密码"
        log_error "您也可以稍后手动执行: docker login $PRIVATE_REGISTRY"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    log_info "跳过私有 Registry 登录"
    log_warn "如果拉取镜像失败，请手动登录: docker login $PRIVATE_REGISTRY"
fi

echo ""

log_info "步骤 5/8: 配置环境变量"

if [[ ! -f ".env" ]]; then
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
        log_info "已从 .env.example 创建 .env 文件"
    else
        log_error ".env.example 不存在"
        exit 1
    fi
fi

if grep -q "^POSTGRES_PASSWORD=$" .env; then
    log_warn "⚠️  .env 中数据库密码未设置，请手动编辑 .env 文件设置密码"
    log_warn "   POSTGRES_PASSWORD=your_secure_password"
    read -p "按 Enter 继续..."
fi

if grep -q "^OSS_ACCESS_KEY_SECRET=$" .env; then
    log_warn "⚠️  .env 中 OSS 密钥未设置，请手动编辑 .env 文件设置密钥"
    log_warn "   OSS_ACCESS_KEY_SECRET=your_secret_key"
    read -p "按 Enter 继续..."
fi

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

sed -i.bak "s/^UID=.*/UID=$CURRENT_UID/" .env
sed -i.bak "s/^GID=.*/GID=$CURRENT_GID/" .env
rm -f .env.bak

log_info "✓ UID/GID 已更新: $CURRENT_UID:$CURRENT_GID"

# 按物理内存自动选择配额档：8GB 机器叠加 docker-compose.8g.yml，12GB 用 base 默认值。
# 阈值取 10GB —— 8G 机器实际可见约 7.6G，12G 约 11.6G，10G 能稳定区分两者。
TOTAL_MEM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
if [[ -n "$TOTAL_MEM_MB" ]]; then
    if [[ "$TOTAL_MEM_MB" -lt 10240 ]]; then
        PROFILE_LINE="COMPOSE_FILE=docker-compose.yml:docker-compose.8g.yml"
        log_info "检测到物理内存 ${TOTAL_MEM_MB}MB → 使用 8GB 配额档"
    else
        PROFILE_LINE="# COMPOSE_FILE=docker-compose.yml:docker-compose.8g.yml"
        log_info "检测到物理内存 ${TOTAL_MEM_MB}MB → 使用默认（12GB）配额档"
    fi
    # 已存在该行（含注释形态）则替换，否则追加
    if grep -qE "^#? *COMPOSE_FILE=" .env; then
        sed -i.bak "s|^#\? *COMPOSE_FILE=.*|$PROFILE_LINE|" .env
        rm -f .env.bak
    else
        printf '\n%s\n' "$PROFILE_LINE" >> .env
    fi
else
    log_warn "无法检测物理内存，请手动确认 .env 中的 COMPOSE_FILE 配额档"
fi

if [[ -z "$PC_NUM" ]]; then
    HOSTNAME=$(hostname)
    USERNAME=$(whoami)
    PC_NUM="${USERNAME}-${HOSTNAME}"
    sed -i.bak "s/^PC_NUM=.*/PC_NUM=$PC_NUM/" .env
    rm -f .env.bak
    log_info "✓ PC_NUM 已设置: $PC_NUM"
fi

echo ""

log_info "步骤 6/8: 设置定时清理任务"

if [[ -f "clean_database.sh" ]]; then
    CLEANUP_SCRIPT="$(realpath clean_database.sh)"
    chmod +x "$CLEANUP_SCRIPT"

    if crontab -l 2>/dev/null | grep -q "$CLEANUP_SCRIPT"; then
        log_info "定时清理任务已存在，跳过添加"
    else
        (crontab -l 2>/dev/null; echo "0 2 * * * $CLEANUP_SCRIPT >> $(realpath logs)/cleanup.log 2>&1") | crontab -
        log_info "✓ 定时清理任务已添加：每天凌晨 2:00 执行"
    fi
else
    log_warn "clean_database.sh 不存在，跳过定时任务设置"
fi

echo ""

log_info "步骤 7/8: 拉取 Docker 镜像"
log_warn "这可能需要几分钟时间，请耐心等待..."
echo ""

if docker-compose pull; then
    log_info "✓ Docker 镜像拉取完成"
else
    log_warn "部分镜像拉取失败，可以稍后手动执行: docker-compose pull"
fi

echo ""

log_info "步骤 8/8: 启动服务"

read -p "是否立即启动所有服务？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "启动 Docker 服务..."
    docker-compose up -d

    log_info "等待服务启动（10秒）..."
    sleep 10

    log_info "检查服务状态..."
    docker-compose ps

    echo ""
    log_info "================================================"
    log_info "✓ 装机完成！"
    log_info "================================================"
    echo ""
    log_info "服务访问地址："
    log_info "  - 前端界面: http://localhost:3002"
    log_info "  - 后端API:  http://localhost:3000"
    log_info "  - WebSocket: ws://localhost:8080"
    echo ""
    log_info "常用命令："
    log_info "  - 查看日志: docker-compose logs -f"
    log_info "  - 停止服务: docker-compose down"
    log_info "  - 重启服务: docker-compose restart"
    log_info "  - 查看状态: docker-compose ps"
    echo ""
    log_warn "重要提示："
    log_warn "  1. 请检查 .env 文件中的配置是否正确"
    log_warn "  2. 如需串口设备，请确保 /dev/ttyUSB0 和 /dev/ttyUSB1 可用"
    log_warn "  3. 定时清理任务已设置，日志保存在 logs/cleanup.log"
    log_warn "  4. 建议定期备份 data/ 目录中的数据"
    echo ""
else
    log_info "跳过服务启动，可稍后手动执行: docker-compose up -d"
fi

log_info "================================================"
log_info "装机脚本执行完毕"
log_info "================================================"
