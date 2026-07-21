#!/bin/bash
#
# Cookie Saver - 扩展 ID 同步脚本
#
# 当 archives/extension.pem 发生变化时，运行此脚本自动将新的扩展 ID
# 同步到项目中所有引用了扩展 ID 的文件。
#
# 用法:
#   ./sync-extension-id.sh              # 使用默认 PEM: archives/extension.pem
#   ./sync-extension-id.sh /path/to.pem # 指定 PEM 文件
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PEM_FILE="${1:-$SCRIPT_DIR/extension.pem}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================="
echo " Cookie Saver - 扩展 ID 同步"
echo "=============================="
echo ""

# 1. 检查 PEM 文件
if [ ! -f "$PEM_FILE" ]; then
    echo -e "${RED}❌ 未找到 PEM 文件: $PEM_FILE${NC}"
    exit 1
fi

# 2. 从 PEM 计算扩展 ID
NEW_ID=$(openssl rsa -in "$PEM_FILE" -pubout -outform DER 2>/dev/null \
    | openssl dgst -sha256 -binary \
    | head -c 16 \
    | python3 -c "import sys; data=sys.stdin.buffer.read(); print(''.join(chr(ord('a') + (b >> 4)) + chr(ord('a') + (b & 0xf)) for b in data))")

echo -e "PEM 文件: ${YELLOW}$PEM_FILE${NC}"
echo -e "新扩展 ID: ${GREEN}$NEW_ID${NC}"
echo ""

# 3. 扫描项目中现有的扩展 ID（32位小写字母，出现在 chrome-extension:// 后面）
OLD_IDS=$(grep -roh 'chrome-extension://[a-z]\{32\}' "$PROJECT_DIR" \
    --include='*.json' --include='*.sh' --include='*.bat' --include='*.mobileconfig' \
    --exclude-dir=.git --exclude-dir=releases --exclude-dir=node_modules \
    2>/dev/null \
    | sed 's|chrome-extension://||' \
    | sort -u)

if [ -z "$OLD_IDS" ]; then
    echo -e "${YELLOW}⚠️  未找到任何现有的扩展 ID 引用${NC}"
    echo "  可能项目尚未配置过扩展 ID"
fi

# 4. 逐个替换
CHANGED=0
for OLD_ID in $OLD_IDS; do
    if [ "$OLD_ID" = "$NEW_ID" ]; then
        echo -e "  ID ${GREEN}$OLD_ID${NC} 已是最新，跳过"
        continue
    fi

    echo -e "  替换 ${YELLOW}$OLD_ID${NC} → ${GREEN}$NEW_ID${NC}"

    # 替换所有相关文件
    find "$PROJECT_DIR" \
        \( -name '*.json' -o -name '*.sh' -o -name '*.bat' -o -name '*.mobileconfig' \) \
        -not -path '*/.git/*' -not -path '*/releases/*' -not -path '*/node_modules/*' \
        -exec grep -l "$OLD_ID" {} \; 2>/dev/null \
    | while read -r file; do
        sed -i '' "s/$OLD_ID/$NEW_ID/g" "$file"
        echo -e "    ${GREEN}✓${NC} $(echo "$file" | sed "s|$PROJECT_DIR/||")"
        CHANGED=$((CHANGED + 1))
    done
done

# 5. 重新编译 Go 二进制（如果 Go 可用且二进制存在）
NATIVE_HOST_DIR="$PROJECT_DIR/native-host"
BINARY="$NATIVE_HOST_DIR/biscuit-host"
if [ -f "$BINARY" ] && command -v go &>/dev/null; then
    echo ""
    echo "📦 重新编译 Native Host..."
    cd "$NATIVE_HOST_DIR"
    go build -ldflags="-s -w" -o "$BINARY" .
    echo -e "  ${GREEN}✅ 编译完成${NC}"
fi

echo ""
echo "=============================="
echo -e " ${GREEN}✅ 同步完成！${NC}"
echo "=============================="
echo ""
echo "扩展 ID: $NEW_ID"
echo ""
echo "已更新的文件类型: .json .sh .bat .mobileconfig"
echo "如需重新构建发布包，请运行: cd native-host && ./build.sh <version>"
