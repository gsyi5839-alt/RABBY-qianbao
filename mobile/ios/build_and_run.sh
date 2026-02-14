#!/bin/bash

echo "🔨 开始编译 Rabby iOS..."
echo ""

cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios

# 清理旧的构建
echo "1️⃣ 清理旧的构建..."
xcodebuild -workspace RabbyMobile.xcworkspace \
           -scheme RabbyMobile \
           -configuration Debug \
           -sdk iphonesimulator \
           clean > /dev/null 2>&1

echo "2️⃣ 开始编译..."
xcodebuild -workspace RabbyMobile.xcworkspace \
           -scheme RabbyMobile \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,id=37936EEB-0BA1-4074-9576-716DE18D2C15' \
           build 2>&1 | tee /tmp/xcode_final_build.log

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 编译成功！"
    echo ""
    echo "3️⃣ 安装到模拟器..."

    # 查找生成的 .app 文件
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/RabbyMobile-*/Build/Products/Debug-iphonesimulator -name "RabbyMobile.app" 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ]; then
        xcrun simctl install 37936EEB-0BA1-4074-9576-716DE18D2C15 "$APP_PATH"
        echo "✅ 应用已安装到模拟器"
        echo ""
        echo "4️⃣ 启动应用..."
        xcrun simctl launch 37936EEB-0BA1-4074-9576-716DE18D2C15 com.bocail.pay
        echo ""
        echo "🎉 Rabby Wallet 已在模拟器中运行！"
    else
        echo "⚠️  找不到编译的应用"
    fi
else
    echo ""
    echo "❌ 编译失败，查看错误信息："
    grep -A 5 "error:" /tmp/xcode_final_build.log | tail -20
fi
