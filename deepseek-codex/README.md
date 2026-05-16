# deepseek-codex

让 [OpenAI Codex CLI](https://github.com/openai/codex) 接入 DeepSeek 模型的协议转换代理。

## 一键安装

下载解压后，选择对应系统的安装方式：

**Windows 图形界面（推荐）：**
```
双击「安装程序.cmd」
```
粘贴 API 密钥 → 选择模型 → 开始安装。之后在任何 cmd 输入 `codex.cmd` 即可运行。

**Windows 命令行：**
```
双击 install.cmd
```

**macOS / Linux：**
```bash
./install.sh
```

安装程序会自动：
1. 检查 Node.js 和 Codex CLI 是否已安装
2. 引导你填入 DeepSeek API 密钥
3. 配置 `~/.codex/config.toml`
4. **将安装目录加入 PATH**（之后在任何位置输入 `codex.cmd` 都能运行）
5. 可选创建桌面快捷方式

## 原理

Codex CLI v0.130.0 只支持 OpenAI Responses API，而 DeepSeek 提供的是 Chat Completions API。`proxy/proxy.mjs` 是一个本地代理，在两者之间做实时协议转换，让 Codex CLI 无需降级即可使用 DeepSeek 模型。

## 前置条件

- **Node.js 18+** — [下载](https://nodejs.org/)
- **Codex CLI** — `npm install -g @openai/codex` 或从 [GitHub Releases](https://github.com/openai/codex/releases) 安装
- **DeepSeek API 密钥** — [申请](https://platform.deepseek.com/api_keys)

## 快速开始

### 1. 配置 API 密钥

本项目通过 `CODEX_API_KEY` 环境变量读取密钥，**脚本和配置文件中不会存储你的密钥**。

**方法 A：使用 .env 文件（推荐）**

```bash
cp .env.example .env
```

然后编辑 `.env` 文件，将 `sk-your-key-here` 替换为你的真实密钥：

```
# 修改前
CODEX_API_KEY=sk-your-key-here

# 修改后（示例）
CODEX_API_KEY=sk-8fa2071cca544fbf907ae866783ce65d
```

`.env` 文件已在 `.gitignore` 中，不会被提交到 GitHub。

**方法 B：使用环境变量**

```bash
# macOS / Linux
export CODEX_API_KEY="sk-你的密钥"

# Windows (cmd)
set CODEX_API_KEY=sk-你的密钥
```

### 2. 配置 Codex CLI

编辑 `~/.codex/config.toml`（如果目录不存在则创建），写入以下内容：

```toml
model = "deepseek-v4-pro"
model_provider = "deepseek-proxy"
disable_response_storage = true

[model_providers.deepseek-proxy]
name = "DeepSeek (via proxy)"
base_url = "http://127.0.0.1:17890/v1"
env_key = "CODEX_API_KEY"
wire_api = "responses"

[windows]
sandbox = "elevated"
```

> **注意：** `env_key = "CODEX_API_KEY"` 告诉 Codex CLI 从环境变量读取 API 密钥并发送给代理。如果不想设环境变量，也可以把密钥直接写在 URL 里：`base_url = "http://127.0.0.1:17890/v1"`，前提是你修改了 `proxy/proxy.mjs` 中的 `UPSTREAM_API_KEY`。

### 3. 运行

**macOS / Linux：**

```bash
# 进入项目目录
cd deepseek-codex

# 首次：复制配置模板并填入密钥
cp .env.example .env
# 编辑 .env...

# 交互模式（推荐）
./codex.sh

# 直接执行任务
./codex.sh exec "写一个贪吃蛇游戏"
```

**Windows：**

```cmd
:: 进入项目目录
cd deepseek-codex

:: 首次：复制配置模板
copy .env.example .env
:: 编辑 .env 填入密钥...

:: 双击 codex.cmd，或者在 cmd 中运行：
codex.cmd

:: 直接执行任务：
codex.cmd exec "写一个贪吃蛇游戏"
```

## 切换模型（例如换成 DeepSeek V4 Flash）

本项目的默认模型是 `deepseek-v4-pro`。如果想换成 DeepSeek V4 Flash 或其他模型，需要改两个地方：

### 步骤 1：修改 Codex CLI 配置

编辑 `~/.codex/config.toml`，把 `model` 改成你想要的模型 ID：

```toml
# 改为 deepseek-v4-flash
model = "deepseek-v4-flash"

# 或者改为其他 DeepSeek 模型
# model = "deepseek-chat"
# model = "deepseek-reasoner"
```

### 步骤 2：添加模型的元数据（可选但推荐）

如果没有模型元数据，Codex CLI 会显示警告 "Model metadata not found"。要消除警告，编辑 `models/deepseek.json`，在 `models` 数组中添加一个新条目：

```json
{
  "models": [
    // ... 已有模型 ...
    {
      "slug": "deepseek-v4-flash",
      "display_name": "DeepSeek V4 Flash",
      "description": "DeepSeek V4 Flash - 轻量快速模型",
      "default_reasoning_level": "medium",
      "supported_reasoning_levels": [
        {"effort": "low", "description": "Fast responses"},
        {"effort": "medium", "description": "Balanced"},
        {"effort": "high", "description": "Deep reasoning"}
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 10,
      "additional_speed_tiers": [],
      "service_tiers": [],
      "availability_nux": null,
      "upgrade": null,
      "supports_reasoning_summaries": false,
      "default_reasoning_summary": "none",
      "support_verbosity": false,
      "default_verbosity": "low",
      "apply_patch_tool_type": "freeform",
      "web_search_tool_type": "text",
      "truncation_policy": {"mode": "tokens", "limit": 10000},
      "supports_parallel_tool_calls": true,
      "supports_image_detail_original": false,
      "context_window": 1000000,
      "max_context_window": 1000000,
      "effective_context_window_percent": 85,
      "experimental_supported_tools": ["shell", "update_plan"],
      "input_modalities": ["text"],
      "supports_search_tool": false,
      "base_instructions": "You are Codex CLI, a coding agent. You work in a terminal environment and can execute shell commands."
    }
  ]
}
```

### 步骤 3：确保代理能识别新模型

代理（`proxy/proxy.mjs`）会自动透传 `model` 字段给 DeepSeek API，所以不需要修改代理代码。如果 DeepSeek 返回 404 表示模型名不存在，请检查 DeepSeek 官方文档确认正确的模型 ID。

## 环境变量参考

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CODEX_API_KEY` | DeepSeek API 密钥（必填） | — |
| `UPSTREAM_API_KEY` | 同上，代理专用（脚本会自动设置） | 同 `CODEX_API_KEY` |
| `DEEPSEEK_API_KEY` | Codex CLI 读取此变量（脚本会自动设置） | 同 `CODEX_API_KEY` |
| `PROXY_PORT` | 本地代理监听端口 | 17890 |

优先级：**环境变量 > `.env` 文件**

## 项目结构

```
deepseek-codex/
├── README.md            # 本文档
├── .env.example         # 配置模板（复制为 .env 并填入密钥）
├── .gitignore           # 排除 .env、node_modules 等
├── codex.sh             # macOS / Linux 启动脚本
├── codex.cmd            # Windows 启动脚本（双击运行）
├── proxy/
│   └── proxy.mjs        # Responses API → Chat Completions 协议转换
└── models/
    └── deepseek.json    # 模型元数据（消除 Codex CLI 警告）
```

## 附录：详细使用说明

### 安装器说明

**Windows 图形安装器（install-ui.hta）**
- 双击运行，粘贴 API 密钥 → 选择模型 → 开始安装
- 安装前会自动验证 API 密钥是否有效
- 检测到 Node.js 未安装时会弹出下载指引
- 检测到 Codex CLI 未安装时会自动安装（国内镜像 → 官方源）
- 可选：创建桌面快捷方式、开机自启代理
- 安装完成后在任何 cmd 输入 `codex.cmd` 即可运行

**Windows 命令行安装器（install.cmd）**
- 同上的 CLI 版本，无图形界面
- 会自动复制文件、配置 Codex CLI、加入 PATH

### 设置工具（settings.hta）

安装后可在桌面或安装目录打开 `settings.hta`，功能：
- **切换模型**：在 DeepSeek V4 Pro 和 V4 Flash 之间一键切换
- **开机自启**：开关 proxy 是否随系统启动
- **打开配置文件**：用记事本直接编辑 Codex CLI 配置

### 开机自启原理

勾选开机自启后，安装器会：
1. 创建 `start-proxy.vbs` — 一个静默启动脚本，无命令行窗口
2. 写入注册表 `HKCU\...\Run\deepseek-codex-proxy`
3. 每次开机自动启动 proxy，后台运行
4. 之后打开 cmd 直接输入 `codex.cmd` 即用（proxy 已在运行）

无需开机自启时，在 `settings.hta` 中关闭即可。

### 协议转换代理（proxy/proxy.mjs）

Codex CLI 使用 OpenAI Responses API，DeepSeek 使用 Chat Completions API。
本地代理在 `http://127.0.0.1:17890` 监听，做实时协议转换：

```
Codex CLI  →  Responses API  →  本地代理  →  Chat Completions API  →  DeepSeek
```

代理仅用 Node.js 内置模块（无第三方依赖），内存占用极低。

### 常见问题

**Q：安装时卡在「正在安装 Codex CLI...」怎么办？**
A：网络问题导致 npm 下载超时。可关闭重试，或手动运行 `npm install -g @openai/codex`。

**Q：codex.cmd 提示「CODEX_API_KEY 未设置」？**
A：检查安装目录下的 `.env` 文件是否存在，且内容格式为 `CODEX_API_KEY=sk-...`。

**Q：模型切换后不生效？**
A：切换模型后需要重启 Codex CLI。如果用的是 `codex.cmd` 启动，关闭 cmd 重新运行。

**Q：如何完全卸载？**
A：三种方式：
- 打开 `install-ui.hta`，点击底部「卸载」
- 运行 `uninstall.cmd`
- 手动删除 `%USERPROFILE%\deepseek-codex` 目录，从 PATH 中移除，删除注册表 `HKCU\...\Run\deepseek-codex-proxy`

**Q：Node.js 到哪下载？**
A：官网 https://nodejs.org/ 或中文镜像 https://nodejs.cn/，下载左侧 LTS 版安装即可。

**Q：可以自己加其他模型吗？**
A：可以。编辑 `~/.codex/config.toml` 改 `model` 字段，同时在 `models/deepseek.json` 中添加对应的模型元数据。

### macOS / Linux 用户说明

**安装**
```bash
# 下载解压后
chmod +x install.sh
./install.sh
```
安装器会自动检测 Node.js 版本（需 ≥ 18）、自动安装 Codex CLI。

**运行**
```bash
cd ~/deepseek-codex
./codex.sh                 # 交互模式
./codex.sh exec "任务"     # 直接执行
```

**开机自启（macOS）**
```bash
# 创建 plist 让 proxy 随用户登录启动
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.deepseek-codex.proxy.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.deepseek-codex.proxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>$HOME/deepseek-codex/proxy/proxy.mjs</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.deepseek-codex.proxy.plist
```

**开机自启（Linux）**
```bash
# 使用 systemd 用户服务
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/deepseek-codex-proxy.service << EOF
[Unit]
Description=DeepSeek Codex Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node $HOME/deepseek-codex/proxy/proxy.mjs
Restart=on-failure
Environment=UPSTREAM_API_KEY=your-key-here

[Install]
WantedBy=default.target
EOF
systemctl --user enable deepseek-codex-proxy.service
systemctl --user start deepseek-codex-proxy.service
```

**卸载**
```bash
rm -rf ~/deepseek-codex
rm -f ~/.codex/config.toml   # 可选：同时也清理 Codex CLI 配置
# 如果设置了开机自启：
launchctl unload ~/Library/LaunchAgents/com.deepseek-codex.proxy.plist  # macOS
rm ~/Library/LaunchAgents/com.deepseek-codex.proxy.plist
# systemctl --user disable deepseek-codex-proxy.service                  # Linux
```
