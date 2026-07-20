@echo off
setlocal enabledelayedexpansion

echo ==============================
echo  Cookie Saver - Windows 安装脚本
echo ==============================
echo.

:: 检查 Go 是否安装
where go >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未找到 Go 编译器
    echo 请先安装 Go: https://go.dev/dl/
    echo.
    pause
    exit /b 1
)

echo [1/3] 编译 Native Host...
cd /d "%~dp0"
go build -ldflags="-s -w" -o biscuit-host.exe .
if %errorlevel% neq 0 (
    echo [错误] 编译失败
    pause
    exit /b 1
)
echo   编译成功: biscuit-host.exe
echo.

:: 获取扩展 ID
echo [2/3] 设置扩展 ID
echo.
echo 请先在 chrome://extensions 中：
echo   1. 开启「开发者模式」
echo   2. 点击「加载已解压的扩展程序」，选择 extension/ 目录
echo   3. 复制显示的扩展 ID
echo.
set /p EXTENSION_ID="粘贴扩展 ID 后回车: "

if "%EXTENSION_ID%"=="" (
    echo [错误] 扩展 ID 不能为空
    pause
    exit /b 1
)

:: 创建 manifest 文件
echo [3/3] 安装 Native Messaging Host...

set "MANIFEST_DIR=%LOCALAPPDATA%\Google\Chrome\User Data\NativeMessagingHosts"
if not exist "%MANIFEST_DIR%" mkdir "%MANIFEST_DIR%"

set "BINARY_PATH=%~dp0biscuit-host.exe"
set "BINARY_PATH=%BINARY_PATH:\=\\%"

(
echo {
echo   "name": "com.biscuitbox.host",
echo   "description": "Cookie Saver Native Messaging Host",
echo   "path": "%BINARY_PATH%",
echo   "type": "stdio",
echo   "allowed_origins": ["chrome-extension://%EXTENSION_ID%/"]
echo }
) > "%MANIFEST_DIR%\com.biscuitbox.host.json"

echo   Manifest 已安装到: %MANIFEST_DIR%\com.biscuitbox.host.json
echo.

echo ==============================
echo  安装完成！
echo ==============================
echo.
echo 现在可以：
echo   1. 重新加载 Chrome 扩展
echo   2. 点击扩展图标测试
echo.
pause
