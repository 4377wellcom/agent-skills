@echo off
chcp 65001 >nul
title deepseek-codex 卸载程序
cd /d %~dp0
setlocal enabledelayedexpansion

set INSTALL_DIR=%USERPROFILE%\deepseek-codex

echo ============================================
echo   deepseek-codex 卸载程序
echo ============================================
echo.
echo 将执行以下操作：
echo   1. 删除 %INSTALL_DIR%
echo   2. 从 PATH 中移除
echo   3. 删除桌面快捷方式
echo   4. 可选清理 Codex CLI 配置
echo.
set /p CONFIRM=确认卸载？(Y/N)
if /i not "%CONFIRM%"=="Y" exit /b

echo.

REM ---- 关闭代理（按端口 17890 精确查找）----
echo [1/4] 停止代理...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":17890 "') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo     已停止代理进程

REM ---- 删除安装目录 ----
echo [2/4] 删除安装文件...
if exist "%INSTALL_DIR%" (
    rmdir /s /q "%INSTALL_DIR%" 2>nul
    echo     已删除 %INSTALL_DIR%
) else (
    echo     安装目录不存在，跳过
)

REM ---- 清理 PATH ----
echo [3/4] 清理 PATH...
for /f "skip=2 tokens=3*" %%a in ('reg query HKCU\Environment /v PATH 2^>nul') do set USER_PATH=%%a%%b
echo %USER_PATH% | findstr /I "%INSTALL_DIR%" >nul
if not errorlevel 1 (
    set NEW_PATH=%USER_PATH:;%INSTALL_DIR%=%
    set NEW_PATH=%NEW_PATH:%INSTALL_DIR%;=%
    set NEW_PATH=%NEW_PATH:%INSTALL_DIR%=%
    setx PATH "%NEW_PATH%" >nul
    echo     已从 PATH 中移除 %INSTALL_DIR%
) else (
    echo     PATH 中未找到，跳过
)

REM ---- 删除桌面快捷方式 ----
echo [4/4] 删除桌面快捷方式...
if exist "%USERPROFILE%\Desktop\codex-deepseek.cmd" (
    del "%USERPROFILE%\Desktop\codex-deepseek.cmd"
    echo     已删除桌面快捷方式
) else (
    echo     桌面快捷方式不存在，跳过
)
echo.

REM ---- 可选清理 Codex CLI 配置 ----
set CODEX_CONFIG=%USERPROFILE%\.codex\config.toml
if exist "%CODEX_CONFIG%" (
    findstr "deepseek-proxy" "%CODEX_CONFIG%" >nul
    if not errorlevel 1 (
        echo.
        set /p CLEAN_CONFIG=检测到 Codex CLI 配置中包含 DeepSeek，是否清理？(Y/N)
        if /i "!CLEAN_CONFIG!"=="Y" (
            echo     请在 %CODEX_CONFIG% 中手动删除 deepseek 相关配置段
            start notepad "%CODEX_CONFIG%"
        )
    )
)

echo.
echo ============================================
echo   卸载完成！
echo   请重新打开 cmd 使 PATH 更改生效。
echo ============================================
pause
