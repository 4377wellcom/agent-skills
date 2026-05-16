#!/usr/bin/env bash
# deepseek-codex 安装脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
LOG_FILE="$HOME/deepseek-codex/install.log"

echo "============================================"
echo "  deepseek-codex 安装程序"
echo "  让 Codex CLI 接入 DeepSeek 模型"
echo "============================================"
echo ""

mkdir -p "$HOME/deepseek-codex"
echo "[$(date)] 开始安装" >> "$LOG_FILE"

# ---- 检查 Node.js ----
echo "[1/4] 检查 Node.js..."
echo "[$(date)] 检查 Node.js..." >> "$LOG_FILE"
if ! command -v node &>/dev/null; then
    echo "[$(date)] Node.js 未安装" >> "$LOG_FILE"
    echo "  [!] Node.js 未安装，无法继续"
    echo ""
    echo "     Codex CLI 和协议代理都需要 Node.js 运行环境。"
    echo ""
    echo "     下载安装步骤："
    echo "       1. 打开 https://nodejs.org/ 或 https://nodejs.cn/"
    echo "       2. 下载左侧 LTS（长期支持版）"
    echo "       3. 安装后重新运行本安装程序"
    echo ""
    exit 1
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
echo "     Node.js 版本: $(node -v)"
echo "[$(date)] Node.js 版本: $(node -v)" >> "$LOG_FILE"
if [ "$NODE_VER" -lt 18 ]; then
    echo "[$(date)] Node.js 版本过低: v$NODE_VER" >> "$LOG_FILE"
    echo "  [!] Node.js 版本过低（v$NODE_VER），需要 v18 以上"
    echo "     请到 https://nodejs.org/ 下载最新 LTS 版"
    exit 1
fi

# ---- 检查/安装 Codex CLI ----
echo "[2/4] 检查 Codex CLI..."
echo "[$(date)] 检查 Codex CLI..." >> "$LOG_FILE"
if ! command -v codex &>/dev/null; then
    echo "  未检测到 Codex CLI，正在自动安装..."
    echo "[$(date)] Codex CLI 未安装，开始自动安装" >> "$LOG_FILE"
    echo "  尝试国内镜像源..."
    echo "[$(date)] 尝试 npmmirror 安装..." >> "$LOG_FILE"
    npm install -g @openai/codex --registry=https://registry.npmmirror.com 2>>"$LOG_FILE" || true
    if ! command -v codex &>/dev/null; then
        echo "  镜像源失败，尝试官方源..."
        echo "[$(date)] npmmirror 失败，尝试官方源..." >> "$LOG_FILE"
        npm install -g @openai/codex 2>>"$LOG_FILE" || true
    fi
    if ! command -v codex &>/dev/null; then
        echo "[$(date)] Codex CLI 安装失败" >> "$LOG_FILE"
        echo "  [!] Codex CLI 安装失败"
        echo "     请手动运行: npm install -g @openai/codex"
        exit 1
    fi
    echo "  Codex CLI 安装成功"
    echo "[$(date)] Codex CLI 安装成功" >> "$LOG_FILE"
else
    echo "  Codex CLI 已安装"
    echo "[$(date)] Codex CLI 已安装" >> "$LOG_FILE"
fi

# ---- 配置 API 密钥 ----
echo "[3/4] 配置 API 密钥..."
echo "[$(date)] 配置 API 密钥" >> "$LOG_FILE"
if [ -f ".env" ]; then
    cp .env "$HOME/deepseek-codex/.env" 2>/dev/null || true
    echo "  检测到已有 .env 文件，已复制"
else
    cp .env.example "$HOME/deepseek-codex/.env" 2>/dev/null || true
    cp .env.example .env 2>/dev/null || true
    echo "  已创建 .env 文件"
    echo ""
    echo "  请编辑 .env，将 sk-your-key-here 替换为你的 DeepSeek API 密钥"
    echo "  获取密钥: https://platform.deepseek.com/api_keys"
    echo ""
    if command -v nano &>/dev/null; then
        echo "  正在用 nano 打开 .env..."
        nano .env
    elif command -v vim &>/dev/null; then
        echo "  正在用 vim 打开 .env..."
        vim .env
    else
        echo "  请手动编辑 .env: vi .env"
    fi
    echo ""
    read -p "  填入密钥后按回车继续..."
fi

# ---- 配置 Codex CLI ----
echo "[4/4] 配置 Codex CLI..."
echo "[$(date)] 配置 Codex CLI" >> "$LOG_FILE"
CODEX_CONFIG="$HOME/.codex/config.toml"
mkdir -p "$HOME/.codex"

CAT_CONFIG=$(cat << 'CONFIG'
# Codex CLI -> DeepSeek (via proxy)
model = "deepseek-v4-pro"
model_provider = "deepseek-proxy"
disable_response_storage = true

[model_providers.deepseek-proxy]
name = "DeepSeek (via proxy)"
base_url = "http://127.0.0.1:17890/v1"
env_key = "CODEX_API_KEY"
wire_api = "responses"
CONFIG
)

if [ -f "$CODEX_CONFIG" ]; then
    if grep -q "deepseek-proxy" "$CODEX_CONFIG" 2>/dev/null; then
        echo "  DeepSeek 代理配置已存在"
    else
        echo "$CAT_CONFIG" >> "$CODEX_CONFIG"
        echo "  已追加 DeepSeek 配置到 $CODEX_CONFIG"
    fi
else
    echo "$CAT_CONFIG" > "$CODEX_CONFIG"
    echo "  已创建配置: $CODEX_CONFIG"
fi

# 复制核心文件
cp "proxy/proxy.mjs" "$HOME/deepseek-codex/proxy/" 2>/dev/null || true
cp "models/deepseek.json" "$HOME/deepseek-codex/models/" 2>/dev/null || true
cp codex.sh "$HOME/deepseek-codex/codex.sh" 2>/dev/null || true
chmod +x "$HOME/deepseek-codex/codex.sh" 2>/dev/null || true

# ---- 加入 PATH ----
echo "[$(date)] 加入 PATH" >> "$LOG_FILE"
SHELL_RC=""
if [ -n "$BASH_VERSION" ]; then
  SHELL_RC="$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.profile"
fi
if [ -n "$SHELL_RC" ] && [ ! -f "$SHELL_RC" ]; then
  touch "$SHELL_RC"
fi
if [ -n "$SHELL_RC" ] && ! grep -q "deepseek-codex" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# deepseek-codex" >> "$SHELL_RC"
  echo 'export PATH="$HOME/deepseek-codex:$PATH"' >> "$SHELL_RC"
  echo "  已将 ~/deepseek-codex 加入 PATH（$SHELL_RC）"
  echo "  请运行 source $SHELL_RC 或重新打开终端"
else
  echo "  PATH 中已存在，跳过"
fi

echo "[$(date)] 安装完成" >> "$LOG_FILE"
echo ""
echo "============================================"
echo "   安装完成！"
echo ""
echo "   使用方法:"
echo "     cd ~/deepseek-codex"
echo "     ./codex.sh          交互模式"
echo "     ./codex.sh exec ... 直接执行任务"
echo ""
echo "============================================"
