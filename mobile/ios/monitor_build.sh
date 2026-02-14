#!/bin/bash

echo "🔨 Rabby iOS 编译进度监控"
echo "================================"
echo ""

BUILD_LOG="/tmp/xcode_build.log"
LAST_LINE=0

while true; do
    if [ -f "$BUILD_LOG" ]; then
        # 获取新行数
        CURRENT_LINES=$(wc -l < "$BUILD_LOG")

        if [ $CURRENT_LINES -gt $LAST_LINE ]; then
            # 显示新的编译信息
            tail -n +$((LAST_LINE + 1)) "$BUILD_LOG" | grep -E "Compiling|Linking|BUILD|error:|warning:" | tail -5
            LAST_LINE=$CURRENT_LINES

            # 检查是否完成
            if grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
                echo ""
                echo "✅ 编译成功！"
                exit 0
            elif grep -q "BUILD FAILED" "$BUILD_LOG"; then
                echo ""
                echo "❌ 编译失败，错误信息："
                grep -A 5 "error:" "$BUILD_LOG" | tail -20
                exit 1
            fi
        fi
    fi

    sleep 2
done
