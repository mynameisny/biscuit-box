#!/bin/bash
# 创建干净的新分支并推送（无历史敏感记录）

set -e

cd "$(dirname "$0")"

echo "=========================================="
echo " 创建干净分支并推送（无历史记录）"
echo "=========================================="
echo ""

# 1. 创建孤儿分支（无历史记录）
echo "[1/5] 创建孤儿分支 clean-main..."
git checkout --orphan clean-main

# 2. 清空暂存区
echo "[2/5] 清空暂存区..."
git rm -rf --cached . 2>/dev/null || true

# 3. 添加所有文件并提交
echo "[3/5] 添加文件并提交..."
git add .
git commit -m "feat: initial commit - Cookie Saver Chrome extension with Native Messaging Host"

# 4. 删除旧的 main 分支并重命名
echo "[4/5] 重命名分支为 main..."
git branch -D main 2>/dev/null || true
git branch -m main

# 5. 强制推送到远程
echo "[5/5] 强制推送到远程..."
git remote set-url origin https://github.com/mynameisny/biscuit-box.git
git push -f origin main

echo ""
echo "=========================================="
echo " ✅ 完成！"
echo "=========================================="
echo ""
echo "远程仓库现在只有一个干净的提交，没有任何历史记录。"
echo "所有敏感信息已被清除。"
