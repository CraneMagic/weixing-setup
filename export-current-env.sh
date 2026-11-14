#!/usr/bin/env bash
# 导出运行中的镜像摘要，用于相同平台的设备。
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output="$script_dir/.env.current"
if [[ $# -gt 0 ]]; then
    if [[ "$1" == '-h' || "$1" == '--help' ]]; then
        echo "用法: $0 [--output 路径]"
        exit 0
    fi
    if [[ $# -ne 2 || "$1" != '--output' ]]; then
        echo "用法: $0 [--output 路径]" >&2
        exit 1
    fi
    output="$2"
fi
fail() {
    echo "导出失败：$*；原有输出文件保持不变。" >&2
    exit 1
}
command -v docker >/dev/null 2>&1 || fail '未安装 Docker'
temporary="$(mktemp "${output}.tmp.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
cat > "$temporary" <<'HEADER'
# 当前运行的 Weixing 镜像版本；复制到同平台目标设备的 setup/.env.local。
# 使用 ./compose.sh pull 和 ./compose.sh up -d 应用。
# latest@sha256 固定当前镜像摘要，不随 latest 更新。
# 仅包含镜像版本，不包含密码、网络或设备配置。
HEADER
export_service() {
    local variable="$1" repository="registry.yijunstudio.xyz/$2"
    shift 2
    local name state image_id digests digest version first_id='' first_version=''
    for name in "$@"; do
        state="$(docker container inspect --format '{{.State.Running}}' "$name")" || fail "无法读取容器 $name"
        [[ "$state" == true ]] || fail "$name 未运行"
        image_id="$(docker container inspect --format '{{.Image}}' "$name")" || fail "无法读取 $name 的镜像"
        digests="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$image_id")" || fail "无法读取镜像 $image_id"
        digest=''
        while IFS= read -r candidate; do
            if [[ "$candidate" == "$repository@sha256:"* ]]; then
                digest="${candidate#*@}"
                break
            fi
        done <<< "$digests"
        [[ -n "$digest" ]] || fail "$name 缺少 $repository 的仓库摘要"
        version="latest@$digest"
        if [[ -n "$first_id" && ( "$image_id" != "$first_id" || "$version" != "$first_version" ) ]]; then
            fail "$variable 对应的容器镜像版本不一致"
        fi
        first_id="$image_id"
        first_version="$version"
    done
    printf '%s=%s\n' "$variable" "$first_version" >> "$temporary"
}
export_service WEBSOCKET_TAG weixing-websocket-server websocket-server
export_service UDP_TAG weixing-udp-server udp-server
export_service TCP_SERVER_TAG weixing-tcp-server tcp-server-1 tcp-server-2 tcp-server-3
export_service SERVICE_TAG weixing-service backend-service
export_service FRONTEND_TAG weixing-frontend frontend
export_service CV_TAG weixing-cv weixing-cv
export_service HEARTBEAT_TAG weixing-heartbeat weixing-heartbeat
mv -f -- "$temporary" "$output"
echo "已生成 $output"
