#!/usr/bin/env bash
# 从 setup 目录加载基础配置与可选的本机镜像版本配置。
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if docker compose version >/dev/null 2>&1; then
    compose=(docker compose)
else
    compose=(docker-compose)
fi
args=(--env-file .env)
if [[ -f .env.local ]]; then
    args+=(--env-file .env.local)
fi
exec "${compose[@]}" "${args[@]}" "$@"
