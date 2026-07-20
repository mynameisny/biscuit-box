#!/bin/bash
#
# Cookie Saver - 跨平台构建脚本
# 编译 macOS / Linux / Windows 三个平台的二进制文件
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$SCRIPT_DIR/releases"
VERSION="${1:-1.0.0}"

echo "=============================="
echo " Cookie Saver - 构建发布包"
echo " 版本: $VERSION"
echo "=============================="

export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

if ! command -v go &>/dev/null; then
    echo "❌ 未找到 go，请先安装: https://go.dev/dl/"
    exit 1
fi

cd "$SCRIPT_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

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

    # 复制安装脚本
    if [ "$goos" = "windows" ]; then
        cp setup.bat "$out_dir/"
    else
        cp setup.sh "$out_dir/"
        chmod +x "$out_dir/setup.sh"
    fi
    cp com.biscuitbox.host.json "$out_dir/"

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
