@echo off
REM Codex CLI + DeepSeek - 在任何 cmd 中直接运行

cd /d %~dp0

REM 检查 Node.js 版本
where node >nul 2>&1
if errorlevel 1 (
    echo [Error] Node.js 未安装
    echo   请安装 Node.js 18+: https://nodejs.org/
    pause
    exit /b 1
)
for /f "tokens=1,2 delims=v." %%a in ('node -v') do (
    if %%b LSS 18 (
        echo [Error] Node.js 版本过低
        echo   当前版本: v%%b
        echo   需要版本: v18 以上
        echo   请到 https://nodejs.org/ 下载最新版
        pause
        exit /b 1
    )
)

REM 自动从 .env 加载密钥（如果环境变量未设）
if "%CODEX_API_KEY%"=="" (
    if exist ".env" (
        for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
            if "%%a"=="CODEX_API_KEY" set CODEX_API_KEY=%%b
        )
    )
)

if "%CODEX_API_KEY%"=="" (
    echo [Error] CODEX_API_KEY 未设置
    echo   编辑 %~dp0.env，加入: CODEX_API_KEY=sk-...
    pause
    exit /b 1
)

set DEEPSEEK_API_KEY=%CODEX_API_KEY%
set UPSTREAM_API_KEY=%CODEX_API_KEY%

REM 检查代理，未运行则启动
curl -s --max-time 1 http://127.0.0.1:17890/v1/responses >nul 2>&1
if not errorlevel 1 goto RUN

echo [Codex] Starting proxy...
start /B "" "node.exe" "%~dp0proxy\proxy.mjs"

:WAIT
timeout /t 1 /nobreak >nul
curl -s --max-time 1 http://127.0.0.1:17890/v1/responses >nul 2>&1
if errorlevel 1 goto WAIT

:RUN
echo [Codex] Ready. Starting Codex CLI...
echo.
codex %*
