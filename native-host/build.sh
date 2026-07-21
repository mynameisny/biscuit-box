#!/bin/bash
#
# Cookie Saver - 跨平台构建脚本
# 编译 macOS / Linux / Windows 三个平台的二进制文件
#
# 扩展 ID 从 archives/extension.pem 自动计算，
# 用户下载后运行 setup 脚本即可，无需手动输入扩展 ID。
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$SCRIPT_DIR/releases"
VERSION="${1:-1.0.0}"
PEM_FILE="$PROJECT_DIR/archives/extension.pem"

echo "=============================="
echo " Cookie Saver - 构建发布包"
echo " 版本: $VERSION"
echo "=============================="

export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

if ! command -v go &>/dev/null; then
    echo "❌ 未找到 go，请先安装: https://go.dev/dl/"
    exit 1
fi

# 从 PEM 计算扩展 ID
if [ ! -f "$PEM_FILE" ]; then
    echo "❌ 未找到 PEM 文件: $PEM_FILE"
    echo "  扩展 ID 需要从 PEM 公钥计算"
    exit 1
fi

EXTENSION_ID=$(openssl rsa -in "$PEM_FILE" -pubout -outform DER 2>/dev/null \
    | openssl dgst -sha256 -binary \
    | head -c 16 \
    | python3 -c "import sys; data=sys.stdin.buffer.read(); print(''.join(chr(ord('a') + (b >> 4)) + chr(ord('a') + (b & 0xf)) for b in data))")

echo "📌 扩展 ID (从 PEM 计算): $EXTENSION_ID"

cd "$SCRIPT_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

generate_readme() {
    local out_dir="$1"
    local platform="$2"

    case "$platform" in
        darwin)
            cat > "$out_dir/README.txt" << 'README_EOF'
====================================
  Cookie Saver - macOS 安装说明
====================================

【安装】

  1. 打开终端（Terminal）
  2. 进入本目录：
     cd /path/to/biscuit-box-macos-*
  3. 运行安装脚本：
     chmod +x setup.sh
     ./setup.sh
  4. 在 Chrome 中安装扩展（如已安装则跳过）：
     - 打开 chrome://extensions
     - 开启「开发者模式」
     - 点击「加载已解压的扩展程序」，选择 extension/ 目录

【卸载】

  运行卸载脚本：
     chmod +x uninstall.sh
     ./uninstall.sh

【文件说明】

  biscuit-host          Native Messaging Host 二进制
  setup.sh              安装脚本
  uninstall.sh          卸载脚本
  com.biscuitbox.host.json  Native Messaging 清单（参考用）
README_EOF
            ;;
        linux)
            cat > "$out_dir/README.txt" << 'README_EOF'
====================================
  Cookie Saver - Linux 安装说明
====================================

【安装】

  1. 打开终端
  2. 进入本目录：
     cd /path/to/biscuit-box-linux-*
  3. 运行安装脚本：
     chmod +x setup.sh
     ./setup.sh
  4. 在 Chrome/Chromium 中安装扩展：
     - 打开 chrome://extensions
     - 开启「开发者模式」
     - 点击「加载已解压的扩展程序」，选择 extension/ 目录

【卸载】

  运行卸载脚本：
     chmod +x uninstall.sh
     ./uninstall.sh

【文件说明】

  biscuit-host          Native Messaging Host 二进制
  setup.sh              安装脚本（同时支持 Chrome 和 Chromium）
  uninstall.sh          卸载脚本
  com.biscuitbox.host.json  Native Messaging 清单（参考用）
README_EOF
            ;;
        windows)
            cat > "$out_dir/README.txt" << 'README_EOF'
====================================
  Cookie Saver - Windows 安装说明
====================================

【安装】

  1. 双击运行 setup.bat
  2. 在 Chrome 中安装扩展：
     - 打开 chrome://extensions
     - 开启「开发者模式」
     - 点击「加载已解压的扩展程序」，选择 extension/ 目录

【卸载】

  手动删除以下文件：
  %LOCALAPPDATA%\Google\Chrome\User Data\NativeMessagingHosts\com.biscuitbox.host.json

【文件说明】

  biscuit-host.exe      Native Messaging Host 二进制
  setup.bat             安装脚本
  com.biscuitbox.host.json  Native Messaging 清单（参考用）
README_EOF
            ;;
    esac
}

build_platform() {
    local goos="$1"
    local goarch="$2"
    local name="$3"
    local ext=""

    if [ "$goos" = "windows" ]; then
        ext=".exe"
    fi

    echo ""
    echo "📦 构建 $name ($goos/$goarch)..."

    local out_dir="$RELEASE_DIR/biscuit-box-$name"
    mkdir -p "$out_dir"

    GOOS="$goos" GOARCH="$goarch" go build -ldflags="-s -w" -o "$out_dir/biscuit-host$ext" .

    # 生成 manifest（使用计算出的扩展 ID）
    cat > "$out_dir/com.biscuitbox.host.json" << EOF
{
  "name": "com.biscuitbox.host",
  "description": "Cookie Saver Native Messaging Host",
  "path": "biscuit-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF

    # 复制安装/卸载脚本 + 生成说明文档
    if [ "$goos" = "windows" ]; then
        cp setup.bat "$out_dir/"
        generate_readme "$out_dir" "windows"
    else
        cp setup.sh "$out_dir/"
        chmod +x "$out_dir/setup.sh"
        cp uninstall.sh "$out_dir/"
        chmod +x "$out_dir/uninstall.sh"
        generate_readme "$out_dir" "$goos"
    fi

    # 打包
    cd "$RELEASE_DIR"
    if [ "$goos" = "windows" ]; then
        zip -r "biscuit-box-$name.zip" "biscuit-box-$name/"
    else
        tar -czf "biscuit-box-$name.tar.gz" "biscuit-box-$name/"
    fi
    rm -rf "biscuit-box-$name"
    cd "$SCRIPT_DIR"

    echo "  ✅ $name 构建完成"
}

build_platform "darwin"  "amd64" "macos-amd64"
build_platform "darwin"  "arm64" "macos-arm64"
build_platform "linux"   "amd64" "linux-amd64"
build_platform "windows" "amd64" "windows-amd64"

echo ""
echo "=============================="
echo " ✅ 构建完成！"
echo "=============================="
echo ""
echo "发布包位于: $RELEASE_DIR/"
ls -lh "$RELEASE_DIR/"
