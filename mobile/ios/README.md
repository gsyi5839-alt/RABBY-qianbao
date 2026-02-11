# React Native iOS App - Setup Guide

## iOS项目结构已创建完成

### 📁 目录结构
```
mobile/ios/
├── RabbyMobile/                    # 主应用目录
│   ├── AppDelegate.h               # 应用委托头文件
│   ├── AppDelegate.mm              # 应用委托实现
│   ├── Info.plist                  # 应用配置文件
│   ├── main.m                      # 应用入口
│   ├── LaunchScreen.storyboard     # 启动屏幕
│   └── Images.xcassets/            # 资源目录
│       ├── Contents.json
│       └── AppIcon.appiconset/     # 应用图标
│           └── Contents.json
├── RabbyMobile.xcodeproj/          # Xcode项目文件
│   ├── project.pbxproj
│   └── xcshareddata/
│       └── xcschemes/
│           └── RabbyMobile.xcscheme
├── Podfile                         # CocoaPods依赖管理
└── .xcode.env                      # Xcode环境配置
```

### ⚙️ 配置信息

**Bundle Identifier**: `com.bocail.pay`  
**Team ID**: `4X7QYL9K9S`  
**Display Name**: Rabby Wallet  
**Version**: 1.0  
**Minimum iOS**: 13.4

### 🔐 权限配置 (Info.plist)

已配置以下权限:
- ✅ **NSFaceIDUsageDescription**: Face ID用于钱包安全和交易认证
- ✅ **NSCameraUsageDescription**: 相机用于扫描二维码
- ✅ **NSPhotoLibraryUsageDescription**: 访问相册选择二维码
- ✅ **NSPhotoLibraryAddUsageDescription**: 保存二维码到相册

### 📦 下一步操作

#### 1. 安装CocoaPods依赖
```bash
cd mobile/ios
pod install
```

#### 2. 复制字体文件
需要将以下字体文件从 `_raw/fonts/` 复制到 `mobile/ios/RabbyMobile/`:
- `lato-bold.woff2` → 转换为 `Lato-Bold.ttf`
- `lato-regular.woff2` → 转换为 `Lato-Regular.ttf`
- `roboto-bold.woff2` → 转换为 `Roboto-Bold.ttf`
- `roboto-medium.woff2` → 转换为 `Roboto-Medium.ttf`
- `roboto-regular.woff2` → 转换为 `Roboto-Regular.ttf`

**字体转换工具**: 
- 在线工具: https://cloudconvert.com/woff2-to-ttf
- 或使用: `npm install -g woff2sfnt-cli`

#### 3. 添加应用图标
在Xcode中打开 `RabbyMobile.xcworkspace`,然后:
1. 选择 `Images.xcassets/AppIcon.appiconset`
2. 拖拽对应尺寸的图标文件

需要的图标尺寸:
- 20x20 @2x, @3x
- 29x29 @2x, @3x
- 40x40 @2x, @3x
- 60x60 @2x, @3x
- 1024x1024 @1x (App Store)

#### 4. 打开项目
```bash
# 使用Xcode打开工作区(重要:打开.xcworkspace而非.xcodeproj)
open mobile/ios/RabbyMobile.xcworkspace
```

#### 5. 运行应用
在Xcode中:
1. 选择目标设备(模拟器或真机)
2. 点击运行按钮(⌘+R)

或使用命令行:
```bash
# 在项目根目录
cd mobile
npx react-native run-ios
```

### 🔧 开发工具

**Xcode**: 15.0+  
**CocoaPods**: 1.14+  
**Node.js**: 22+  
**Watchman**: 推荐安装 (`brew install watchman`)

### 📝 注意事项

1. **首次构建**时,需要先运行 `pod install`
2. 始终打开 `.xcworkspace` 文件,而非 `.xcodeproj`
3. 字体文件必须正确添加并在Info.plist中声明
4. 真机调试需要在Apple Developer账户中配置设备

### 🚀 快速启动命令

```bash
# 1. 安装依赖
cd mobile/ios && pod install && cd ..

# 2. 启动Metro
npm start

# 3. 运行iOS (新终端)
npx react-native run-ios
```

### 🐛 常见问题

**问题1**: `command not found: pod`  
**解决**: 安装CocoaPods `sudo gem install cocoapods`

**问题2**: Xcode构建失败  
**解决**: 清理构建 `cd ios && xcodebuild clean && cd ..`

**问题3**: Metro bundler报错  
**解决**: 清理缓存 `npx react-native start --reset-cache`

---

✅ iOS项目结构已成功创建,可以开始开发了!
