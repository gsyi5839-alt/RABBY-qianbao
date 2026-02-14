# 编译错误修复指南

## 一、重复类型声明修复

### 问题分析
编译器报告以下类型存在重复声明：
- `EIP712Field` (EthereumUtils.swift:256)
- `TypedData` (EthereumUtils.swift:262)
- `PerpsPosition` (PerpsManager.swift:93)
- `TransactionRecord` (StorageManager.swift:355)
- `TypedDataApprovalView` (MessageApprovalView.swift:477)
- `NFTApprovalView` (MiscViews.swift:183)
- `TokenSelectorSheet` (SendTokenView.swift:477)
- `AddressManagementView` (SettingsView.swift:243)
- `ConnectedSitesView` (SettingsView.swift:1409)

### 修复步骤

#### 步骤 1: 检查文件结构

运行以下命令检查重复定义：

```bash
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios

# 检查 EthereumUtils.swift
grep -n "struct EIP712Field\|struct TypedData" RabbyMobile/Core/EthereumUtils.swift

# 检查 PerpsManager.swift
grep -n "struct PerpsPosition" RabbyMobile/Core/PerpsManager.swift

# 检查 StorageManager.swift
grep -n "struct TransactionRecord" RabbyMobile/Core/StorageManager.swift
```

#### 步骤 2: 可能的原因

1. **文件被多次包含** - 检查 project.pbxproj 中是否有重复引用
2. **嵌套定义** - 在extension或其他作用域中有重复定义
3. **import冲突** - GenericJSON等库中可能有同名类型

#### 步骤 3: 修复方法A - 清理Xcode缓存

```bash
# 1. 退出 Xcode (如果打开)
killall Xcode 2>/dev/null

# 2. 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. 清理 module cache
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*

# 4. 清理 build folder
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios
rm -rf build/

# 5. Pod clean
pod deintegrate
pod install

# 6. 重新打开项目
open RabbyMobile.xcworkspace
```

#### 步骤 4: 修复方法B - 添加访问控制

如果类型确实只定义一次，添加显式访问控制：

```swift
// 在 EthereumUtils.swift 中
internal struct EIP712Field: Codable, Equatable {
    let name: String
    let type: String
}

internal struct TypedData: Codable {
    // ...
}
```

#### 步骤 5: 修复方法C - 使用typealias避免冲突

如果GenericJSON库有同名类型：

```swift
// 在文件顶部
import GenericJSON

// 使用完全限定名
typealias RabbyTypedData = TypedData
typealias JSONJSON = GenericJSON.JSON
```

---

## 二、Actor隔离错误修复

### 错误信息
```
DAppConnectSheet.swift:733:95
Main actor-isolated static property 'shared' can not be referenced
from a nonisolated context
```

### 修复方法

打开 `RabbyMobile/Views/DAppBrowser/DAppConnectSheet.swift`，找到第733行附近：

**方法A: 添加 @MainActor 标记**
```swift
@MainActor
func someFunction() {
    let manager = SomeManager.shared // 现在可以访问
}
```

**方法B: 使用 Task @MainActor**
```swift
Task { @MainActor in
    let manager = SomeManager.shared
    // ...
}
```

**方法C: 修改 Manager 的 shared 属性**
```swift
// 在 Manager 类中
nonisolated(unsafe) static let shared = SomeManager()
```

---

## 三、TypedData Codable 不一致修复

### 错误信息
```
Type 'TypedData' does not conform to protocol 'Decodable'
Type 'TypedData' does not conform to protocol 'Encodable'
```

### 原因
`TypedData` 包含 `JSON` 类型（来自GenericJSON），需要正确实现Codable。

### 修复

在 `EthereumUtils.swift` 中，找到 TypedData 定义并添加：

```swift
import GenericJSON

struct TypedData: Codable {
    let types: [String: [EIP712Field]]
    let primaryType: String
    let domain: JSON  // GenericJSON.JSON 已经是 Codable
    let message: JSON

    // 如果仍有问题，手动实现
    enum CodingKeys: String, CodingKey {
        case types, primaryType, domain, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        types = try container.decode([String: [EIP712Field]].self, forKey: .types)
        primaryType = try container.decode(String.self, forKey: .primaryType)
        domain = try container.decode(JSON.self, forKey: .domain)
        message = try container.decode(JSON.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(types, forKey: .types)
        try container.encode(primaryType, forKey: .primaryType)
        try container.encode(domain, forKey: .domain)
        try container.encode(message, forKey: .message)
    }
}
```

---

## 四、SecurityRule Identifiable冗余修复

### 错误信息
```
SecurityRuleDrawer.swift:201:25
Redundant conformance of 'SecurityRule' to protocol 'Identifiable'
```

### 修复

打开 `RabbyMobile/Views/Approval/SecurityRuleDrawer.swift`，找到第201行附近：

**移除冗余的 Identifiable 声明：**
```swift
// 之前
struct SecurityRule: Identifiable, Codable, Identifiable {  // ❌ 重复
    let id: String
}

// 之后
struct SecurityRule: Identifiable, Codable {  // ✅
    let id: String
}
```

---

## 五、完整修复流程

### 推荐执行顺序：

```bash
# 1. 切换到项目目录
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios

# 2. 完全清理
killall Xcode 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/RabbyMobile-*
rm -rf build/

# 3. 重新安装 Pods
pod deintegrate
pod install

# 4. 打开Xcode
open RabbyMobile.xcworkspace

# 5. 在Xcode中：
#    - Product > Clean Build Folder (⇧⌘K)
#    - File > Workspace Settings > Derived Data > Delete
#    - Product > Build (⌘B)
```

### 如果仍有错误：

1. **检查 Swift 版本一致性**
   ```bash
   xcodebuild -showBuildSettings | grep SWIFT_VERSION
   ```

2. **检查 Pods 版本**
   ```bash
   pod --version
   gem list cocoapods
   ```

3. **更新 Pods**
   ```bash
   pod repo update
   pod update
   ```

---

## 六、快速诊断脚本

创建并运行诊断脚本：

```bash
#!/bin/bash
echo "=== Rabby iOS 编译错误诊断 ==="
echo ""

echo "1. 检查重复类型定义..."
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios

find RabbyMobile -name "*.swift" -exec grep -l "struct EIP712Field" {} \;
find RabbyMobile -name "*.swift" -exec grep -l "struct TypedData" {} \;
find RabbyMobile -name "*.swift" -exec grep -l "struct PerpsPosition" {} \;

echo ""
echo "2. 检查 Xcode 版本..."
xcodebuild -version

echo ""
echo "3. 检查 Swift 版本..."
xcodebuild -showBuildSettings 2>/dev/null | grep SWIFT_VERSION | head -1

echo ""
echo "4. 检查 Pod 版本..."
pod --version

echo ""
echo "5. 检查 DerivedData 大小..."
du -sh ~/Library/Developer/Xcode/DerivedData/RabbyMobile-* 2>/dev/null || echo "无缓存"

echo ""
echo "=== 诊断完成 ==="
```

---

## 七、最终建议

如果上述方法都无法解决，考虑：

1. **升级/降级 Xcode**
   - 当前使用: Xcode 26.3.0 RC
   - 建议尝试: Xcode 15.x 稳定版

2. **检查 macOS 版本兼容性**
   ```bash
   sw_vers
   ```

3. **联系项目维护者**
   - 这可能是项目本身的问题
   - 提供完整的错误日志

---

**祝编译顺利！** 🚀
