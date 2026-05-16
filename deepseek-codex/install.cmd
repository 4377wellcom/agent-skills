@echo off
chcp 65001 >nul
title deepseek-codex 安装程序
cd /d %~dp0

set INSTALL_DIR=%USERPROFILE%\deepseek-codex
set LOG_FILE=%INSTALL_DIR%\install.log

echo ============================================
echo   deepseek-codex 安装程序
echo   安装后在任何 cmd 输入 codex.cmd 即可运行
echo ============================================
echo.

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
echo [%date% %time%] 开始安装 > "%LOG_FILE%"

REM ---- 检查 Node.js ----
echo [1/6] 检查 Node.js...
echo [%date% %time%] 检查 Node.js... >> "%LOG_FILE%"
where node >nul 2>&1
if errorlevel 1 (
    echo [!] Node.js 未安装，无法继续安装
    echo [%date% %time%] Node.js 未安装 >> "%LOG_FILE%"
    echo.
    echo     Codex CLI 和协议代理都需要 Node.js 运行环境。
    echo.
    echo     下载安装步骤：
    echo       1. 打开 https://nodejs.org/ 或 https://nodejs.cn/
    echo       2. 下载左侧 LTS（长期支持版）
    echo       3. 运行安装程序，一路点「下一步」即可
    echo       4. 安装完成后重新运行本安装程序
    echo.
    pause
    exit /b 1
)
for /f "tokens=1 delims=v." %%a in ('node -v') do set NODE_MAJOR=%%a
REM node -v 输出 "v18.12.0"，去掉 v 后取第一个 . 前的数字
for /f "tokens=1,2 delims=v." %%a in ('node -v') do (
    if %%b LSS 18 (
        echo [!] Node.js 版本过低（v%%b），需要 v18 以上
        echo [%date% %time%] Node.js 版本过低: v%%b >> "%LOG_FILE%"
        echo.
        echo     请到 https://nodejs.org/ 下载最新 LTS 版安装。
        pause
        exit /b 1
    )
)
echo     Node.js 版本:
node -v
echo [%date% %time%] Node.js 版本: >> "%LOG_FILE%"
node -v >> "%LOG_FILE%"
echo.

REM ---- 检查/安装 Codex CLI ----
echo [2/6] 检查 Codex CLI...
echo [%date% %time%] 检查 Codex CLI... >> "%LOG_FILE%"
where codex >nul 2>&1
if errorlevel 1 (
    echo     未检测到 Codex CLI，正在自动安装...
    echo [%date% %time%] Codex CLI 未安装，开始自动安装 >> "%LOG_FILE%"
    echo     尝试国内镜像源...
    echo [%date% %time%] 尝试 npmmirror 安装... >> "%LOG_FILE%"
    call npm install -g @openai/codex --registry=https://registry.npmmirror.com 2>>"%LOG_FILE%"
    where codex >nul 2>&1
    if errorlevel 1 (
        echo     镜像源失败，尝试官方源...
        echo [%date% %time%] npmmirror 失败，尝试官方源... >> "%LOG_FILE%"
        call npm install -g @openai/codex 2>>"%LOG_FILE%"
    )
    where codex >nul 2>&1
    if errorlevel 1 (
        echo [!] Codex CLI 安装失败
        echo [%date% %time%] Codex CLI 安装失败 >> "%LOG_FILE%"
        echo     请手动运行: npm install -g @openai/codex
        pause
        exit /b 1
    )
    echo     Codex CLI 安装成功
    echo [%date% %time%] Codex CLI 安装成功 >> "%LOG_FILE%"
) else (
    echo     Codex CLI 已安装
    echo [%date% %time%] Codex CLI 已安装 >> "%LOG_FILE%"
)
echo.

REM ---- 复制文件 ----
echo [3/6] 安装文件到 %INSTALL_DIR%...
if not exist "%INSTALL_DIR%\proxy" mkdir "%INSTALL_DIR%\proxy"
if not exist "%INSTALL_DIR%\models" mkdir "%INSTALL_DIR%\models"

copy /Y "%~dp0codex.cmd" "%INSTALL_DIR%\codex.cmd" >nul
copy /Y "%~dp0proxy\proxy.mjs" "%INSTALL_DIR%\proxy\proxy.mjs" >nul
copy /Y "%~dp0models\deepseek.json" "%INSTALL_DIR%\models\deepseek.json" >nul
copy /Y "%~dp0settings.hta" "%INSTALL_DIR%\settings.hta" >nul 2>nul
echo     文件复制完成
echo.

REM ---- 配置 API 密钥 ----
echo [4/6] 配置 API 密钥...
echo [%date% %time%] 配置 API 密钥 >> "%LOG_FILE%"
if exist "%INSTALL_DIR%\.env" (
    echo     检测到已有密钥配置，跳过
) else (
    copy /Y "%~dp0.env.example" "%INSTALL_DIR%\.env" >nul
    echo     已创建 %INSTALL_DIR%\.env
    echo.
    echo     请用记事本打开 .env，将 sk-your-key-here 替换为你的密钥
    echo     获取密钥: https://platform.deepseek.com/api_keys
    echo.
    start notepad "%INSTALL_DIR%\.env"
    pause
)
echo.

REM ---- 配置 Codex CLI ----
echo [5/6] 配置 Codex CLI...
echo [%date% %time%] 配置 Codex CLI >> "%LOG_FILE%"
set CODEX_CONFIG=%USERPROFILE%\.codex\config.toml
if not exist "%USERPROFILE%\.codex\" mkdir "%USERPROFILE%\.codex\"

echo model = "deepseek-v4-pro" > "%CODEX_CONFIG%"
echo model_provider = "deepseek-proxy" >> "%CODEX_CONFIG%"
echo disable_response_storage = true >> "%CODEX_CONFIG%"
echo. >> "%CODEX_CONFIG%"
echo [model_providers.deepseek-proxy] >> "%CODEX_CONFIG%"
echo name = "DeepSeek (via proxy)" >> "%CODEX_CONFIG%"
echo base_url = "http://127.0.0.1:17890/v1" >> "%CODEX_CONFIG%"
echo env_key = "CODEX_API_KEY" >> "%CODEX_CONFIG%"
echo wire_api = "responses" >> "%CODEX_CONFIG%"
echo. >> "%CODEX_CONFIG%"
echo [windows] >> "%CODEX_CONFIG%"
echo sandbox = "elevated" >> "%CODEX_CONFIG%"
echo     已配置 Codex CLI
echo.

REM ---- 加入 PATH + 桌面快捷方式 ----
echo [6/6] 加入系统 PATH...
echo [%date% %time%] 加入 PATH >> "%LOG_FILE%"
for /f "skip=2 tokens=3*" %%p in ('reg query HKCU\Environment /v PATH 2^>nul') do set USER_PATH=%%p%%q
echo %USER_PATH% | findstr /I "%INSTALL_DIR%" >nul
if errorlevel 1 (
    setx PATH "%INSTALL_DIR%;%USER_PATH%" >nul
    echo     已将 %INSTALL_DIR% 加入 PATH
) else (
    echo     PATH 中已存在，跳过
)
echo.
echo 是否创建桌面快捷方式？（输入 Y 创建）
set /p CREATE_SHORTCUT=
if /i "%CREATE_SHORTCUT%"=="Y" (
    echo [%date% %time%] 创建桌面快捷方式 >> "%LOG_FILE%"
    echo @echo off > "%USERPROFILE%\Desktop\codex-deepseek.cmd"
    echo cd /d "%INSTALL_DIR%" >> "%USERPROFILE%\Desktop\codex-deepseek.cmd"
    echo start "" "cmd" /k "codex.cmd" >> "%USERPROFILE%\Desktop\codex-deepseek.cmd"
    copy /Y "%~dp0settings.hta" "%USERPROFILE%\Desktop\settings.hta" >nul 2>nul
    echo     已创建桌面快捷方式
)

echo [%date% %time%] 安装完成 >> "%LOG_FILE%"
echo.
echo ============================================
echo   安装完成！
echo.
echo   现在可以：
echo     1. 重新打开 cmd
echo     2. 输入 codex.cmd 回车即可运行
echo.
echo   或直接双击桌面 codex-deepseek.cmd
echo ============================================
pause
