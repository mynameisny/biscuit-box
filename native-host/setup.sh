#!/bin/bash
#
# Cookie Saver - 一键设置脚本
# 安装 Native Messaging Host manifest
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/biscuit-host"

echo "=============================="
echo " Cookie Saver - 一键设置"
echo "=============================="

# 1. 检查二进制文件
echo ""
echo "[1/3] 检查二进制文件..."
if [ -f "$BINARY" ]; then
    chmod +x "$BINARY"
    echo "  ✅ 二进制已存在: $BINARY ($(du -h "$BINARY" | cut -f1))"
elif command -v go &>/dev/null; then
    echo "  ⚠️  未找到预编译二进制，尝试从源码编译..."
    export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
    cd "$SCRIPT_DIR"
    go build -ldflags="-s -w" -o "$BINARY" .
    chmod +x "$BINARY"
    echo "  ✅ 编译完成: $BINARY ($(du -h "$BINARY" | cut -f1))"
else
    echo "  ❌ 未找到二进制文件且未安装 Go 编译器"
    echo "  请从 GitHub Releases 下载包含预编译二进制的安装包"
    exit 1
fi

# 2. 获取扩展 ID
echo ""
echo "[2/3] 设置扩展 ID"
echo ""
echo "请先在 chrome://extensions 中："
echo "  1. 开启「开发者模式」"
echo "  2. 点击「加载已解压的扩展程序」，选择 extension/ 目录"
echo "  3. 复制显示的扩展 ID"
echo ""
read -p "粘贴扩展 ID 后回车: " EXTENSION_ID

if [ -z "$EXTENSION_ID" ]; then
    echo "❌ 扩展 ID 不能为空"
    exit 1
fi

# 3. 安装 manifest
echo ""
echo "[3/3] 安装 Native Messaging Host..."

case "$(uname)" in
    Darwin)
        MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
        ;;
    Linux)
        MANIFEST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
        mkdir -p "$HOME/.config/chromium/NativeMessagingHosts"
        ;;
    *)
        echo "❌ 不支持的操作系统: $(uname)"
        exit 1
        ;;
esac

mkdir -p "$MANIFEST_DIR"

cat > "$MANIFEST_DIR/com.biscuitbox.host.json" << EOF
{
  "name": "com.biscuitbox.host",
  "description": "Cookie Saver Native Messaging Host",
  "path": "$BINARY",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF
echo "  ✅ Manifest 已安装到: $MANIFEST_DIR/com.biscuitbox.host.json"

# Linux 也安装 Chromium
if [ "$(uname)" = "Linux" ]; then
    cp "$MANIFEST_DIR/com.biscuitbox.host.json" "$HOME/.config/chromium/NativeMessagingHosts/com.biscuitbox.host.json"
    echo "  ✅ Chromium manifest 已安装"
fi

echo ""
echo "=============================="
echo " ✅ 全部完成！"
echo "=============================="
echo ""
echo "现在点击扩展图标即可使用"
