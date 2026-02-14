#!/bin/bash

# Rabby iOS 编译错误自动修复脚本
# 作者: Claude AI
# 日期: 2026-02-14

set -e  # 遇到错误立即退出

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

echo "╔════════════════════════════════════════════════╗"
echo "║  Rabby iOS 编译错误自动修复脚本               ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 步骤1: 关闭Xcode
echo -e "${YELLOW}步骤 1/6:${NC} 关闭 Xcode..."
killall Xcode 2>/dev/null && echo "  ✓ Xcode 已关闭" || echo "  ℹ Xcode 未运行"

# 步骤2: 清理缓存
echo ""
echo -e "${YELLOW}步骤 2/6:${NC} 清理 Xcode 缓存..."
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    # 只删除 RabbyMobile 相关的
    find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "RabbyMobile-*" -exec rm -rf {} + 2>/dev/null || true
    echo "  ✓ DerivedData 已清理"
else
    echo "  ℹ DerivedData 目录不存在"
fi

# 清理 ModuleCache
if [ -d ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/* 2>/dev/null || true
    echo "  ✓ ModuleCache 已清理"
fi

# 步骤3: 清理本地 build 目录
echo ""
echo -e "${YELLOW}步骤 3/6:${NC} 清理项目 build 目录..."
cd "$PROJECT_ROOT"
rm -rf build/ 2>/dev/null || true
echo "  ✓ build 目录已清理"

# 步骤4: 检查并修复 SecurityRule Identifiable 冗余
echo ""
echo -e "${YELLOW}步骤 4/6:${NC} 修复 SecurityRule Identifiable 冗余..."
SECURITY_RULE_FILE="$PROJECT_ROOT/RabbyMobile/Views/Approval/SecurityRuleDrawer.swift"
if [ -f "$SECURITY_RULE_FILE" ]; then
    # 备份原文件
    cp "$SECURITY_RULE_FILE" "$SECURITY_RULE_FILE.bak"

    # 查找并修复重复的 Identifiable
    if grep -q "Identifiable.*Identifiable" "$SECURITY_RULE_FILE"; then
        # 使用 sed 移除重复的 Identifiable (macOS 版本)
        sed -i '' 's/: Identifiable, \([^,]*\), Identifiable/: Identifiable, \1/g' "$SECURITY_RULE_FILE"
        echo "  ✓ SecurityRule 重复 Identifiable 已修复"
    else
        echo "  ℹ 未发现 SecurityRule 重复 Identifiable"
    fi
fi

# 步骤5: 重新安装 Pods
echo ""
echo -e "${YELLOW}步骤 5/6:${NC} 重新安装 CocoaPods 依赖..."
if [ -f "Podfile" ]; then
    echo "  → 运行 pod deintegrate..."
    pod deintegrate 2>/dev/null || true

    echo "  → 运行 pod install..."
    pod install --repo-update || {
        echo -e "  ${RED}✗ pod install 失败${NC}"
        echo "  → 尝试不更新 repo..."
        pod install || {
            echo -e "  ${RED}✗ pod install 仍然失败${NC}"
            exit 1
        }
    }
    echo -e "  ${GREEN}✓ CocoaPods 依赖已安装${NC}"
else
    echo -e "  ${RED}✗ Podfile 未找到${NC}"
    exit 1
fi

# 步骤6: 诊断重复定义
echo ""
echo -e "${YELLOW}步骤 6/6:${NC} 诊断重复类型定义..."

echo "  → 检查 EIP712Field..."
RESULT=$(find RabbyMobile -name "*.swift" -exec grep -l "struct EIP712Field" {} \; 2>/dev/null)
COUNT=$(echo "$RESULT" | grep -c "swift" || echo "0")
if [ "$COUNT" -eq "1" ]; then
    echo -e "  ${GREEN}✓ EIP712Field 仅定义一次${NC}"
elif [ "$COUNT" -gt "1" ]; then
    echo -e "  ${YELLOW}⚠ EIP712Field 在多个文件中定义:${NC}"
    echo "$RESULT" | sed 's/^/    /'
fi

echo "  → 检查 TypedData..."
RESULT=$(find RabbyMobile -name "*.swift" -exec grep -l "struct TypedData" {} \; 2>/dev/null)
COUNT=$(echo "$RESULT" | grep -c "swift" || echo "0")
if [ "$COUNT" -eq "1" ]; then
    echo -e "  ${GREEN}✓ TypedData 仅定义一次${NC}"
elif [ "$COUNT" -gt "1" ]; then
    echo -e "  ${YELLOW}⚠ TypedData 在多个文件中定义:${NC}"
    echo "$RESULT" | sed 's/^/    /'
fi

echo "  → 检查 PerpsPosition..."
RESULT=$(find RabbyMobile -name "*.swift" -exec grep -l "struct PerpsPosition" {} \; 2>/dev/null)
COUNT=$(echo "$RESULT" | grep -c "swift" || echo "0")
if [ "$COUNT" -eq "1" ]; then
    echo -e "  ${GREEN}✓ PerpsPosition 仅定义一次${NC}"
elif [ "$COUNT" -gt "1" ]; then
    echo -e "  ${YELLOW}⚠ PerpsPosition 在多个文件中定义:${NC}"
    echo "$RESULT" | sed 's/^/    /'
fi

echo "  → 检查 TransactionRecord..."
RESULT=$(find RabbyMobile -name "*.swift" -exec grep -l "struct TransactionRecord" {} \; 2>/dev/null)
COUNT=$(echo "$RESULT" | grep -c "swift" || echo "0")
if [ "$COUNT" -eq "1" ]; then
    echo -e "  ${GREEN}✓ TransactionRecord 仅定义一次${NC}"
elif [ "$COUNT" -gt "1" ]; then
    echo -e "  ${YELLOW}⚠ TransactionRecord 在多个文件中定义:${NC}"
    echo "$RESULT" | sed 's/^/    /'
fi

# 完成
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║  修复完成！                                    ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}接下来请执行以下步骤:${NC}"
echo ""
echo "  1. 打开项目:"
echo "     open RabbyMobile.xcworkspace"
echo ""
echo "  2. 在 Xcode 中:"
echo "     - Product > Clean Build Folder (⇧⌘K)"
echo "     - Product > Build (⌘B)"
echo ""
echo "  3. 如果仍有错误，查看详细修复指南:"
echo "     cat fix_duplicates.md"
echo ""
echo -e "${YELLOW}提示: 如果修复过程中出错,备份文件在 .bak 扩展名中${NC}"
echo ""
