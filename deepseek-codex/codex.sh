#!/usr/bin/env bash
# Codex CLI + DeepSeek 协议转换代理
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_SCRIPT="$SCRIPT_DIR/proxy/proxy.mjs"
WORKDIR="$SCRIPT_DIR"
PROXY_PORT=17890

# 检查 Node.js 版本
if ! command -v node &>/dev/null; then
    echo "[Error] Node.js 未安装"
    echo "  请安装 Node.js 18+: https://nodejs.org/"
    exit 1
fi
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
    echo "[Error] Node.js 版本过低: $(node -v)"
    echo "  需要 v18 以上，请到 https://nodejs.org/ 下载最新版"
    exit 1
fi

# 加载 .env 文件（如果存在）
if [ -z "${CODEX_API_KEY:-}" ] && [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

if [ -z "${CODEX_API_KEY:-}" ]; then
    echo "[Error] CODEX_API_KEY 未设置"
    echo "  方式1: export CODEX_API_KEY='sk-...'"
    echo "  方式2: cp .env.example .env && 编辑 .env 填入密钥"
    exit 1
fi

# 启动代理（如果未运行）
if curl -sf "http://127.0.0.1:$PROXY_PORT/v1/responses" > /dev/null 2>&1; then
    echo "[Codex] 代理已在运行"
else
    echo "[Codex] 启动代理..."
    UPSTREAM_API_KEY="$CODEX_API_KEY" nohup node "$PROXY_SCRIPT" > /dev/null 2>&1 &
    PROXY_PID=$!
    for i in $(seq 1 10); do
        if curl -sf "http://127.0.0.1:$PROXY_PORT/v1/responses" > /dev/null 2>&1; then
            echo "[Codex] 代理就绪 (PID: $PROXY_PID)"
            break
        fi
        sleep 1
    done
fi

export DEEPSEEK_API_KEY="$CODEX_API_KEY"
export UPSTREAM_API_KEY="$CODEX_API_KEY"
cd "$WORKDIR" || exit 1
echo "[Codex] 启动 Codex CLI..."
echo "---"
exec codex "$@"
