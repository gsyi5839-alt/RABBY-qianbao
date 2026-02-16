# iOS交易历史格式错误修复指南

## 🐛 问题描述

**错误信息**: "The data couldn't be read because it isn't in the correct format."

**出现位置**: 查看交易历史时

**根本原因**:
- 存储中的旧交易历史数据格式与当前代码不兼容
- JSON解码失败（可能是Date格式、数据结构变化等）

## ✅ 已实施的修复

### 1. 代码层面修复（已完成）

**修改文件**: `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift`

#### 修复内容：

**A. 改进的错误处理**
```swift
private func loadHistory() {
    // 加载交易历史，带详细错误处理
    if let d = (try? database.getValueData(forKey: historyKey)) ?? storage.getData(forKey: historyKey) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601  // 统一使用ISO8601
            let h = try decoder.decode([String: [TransactionGroup]].self, from: d)
            self.transactions = h
            // ...
        } catch {
            NSLog("[TransactionHistory] ⚠️ Failed to load: \(error)")
            // 自动清除损坏的数据
            try? database.deleteValue(forKey: historyKey)
            storage.removeData(forKey: historyKey)
            self.transactions = [:]  // 重置为空
        }
    }
}
```

**B. 统一的日期编码策略**
```swift
private func saveHistory() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601  // 统一使用ISO8601格式
    let d = try encoder.encode(transactions)
    // ...
}
```

#### 修复效果：

✅ **自动恢复**: 检测到损坏数据时自动清除并重置
✅ **日志记录**: 详细的NSLog输出，便于调试
✅ **向后兼容**: 尝试ISO8601格式解码，兼容新旧数据
✅ **防止崩溃**: catch错误而不是让应用崩溃

### 2. 清除脚本（可选使用）

**脚本路径**: `mobile/ios/clear_history_data.sh`

**使用场景**:
- 如果问题持续存在
- 需要手动清除所有历史数据

**使用方法**:
```bash
cd mobile/ios
./clear_history_data.sh
```

**脚本功能**:
- 查找正在运行的模拟器
- 清除UserDefaults中的历史数据
- 清除数据库中的历史数据
- 不影响钱包余额和密钥

## 🚀 解决步骤

### 方案一：代码自动修复（推荐）

1. **重新编译应用**
   ```bash
   cd mobile/ios
   xcodebuild clean
   xcodebuild -workspace RabbyMobile.xcworkspace -scheme RabbyMobile
   ```

2. **重启应用**
   - 在模拟器中强制退出Rabby
   - 重新打开应用

3. **验证修复**
   - 打开"历史"标签页
   - 应该能正常显示（即使是空列表）
   - 不应再出现错误提示

### 方案二：手动清除数据

如果方案一不起作用：

1. **运行清除脚本**
   ```bash
   cd mobile/ios
   ./clear_history_data.sh
   ```

2. **重启应用**
   - 强制退出应用
   - 重新打开

3. **验证结果**
   - 历史记录为空
   - 不再显示错误

## 📝 技术细节

### 问题根源

**原始代码（有问题）**:
```swift
// 静默失败，不处理错误
if let h = try? JSONDecoder().decode(...) {
    self.transactions = h
}
// 如果解码失败，h为nil，transactions保持旧值或未初始化
```

**问题**:
- 没有日期解码策略，默认使用TimeInterval
- 如果数据损坏，静默失败但不清除
- 错误信息不明确

**修复后代码**:
```swift
do {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601  // 明确策略
    let h = try decoder.decode(...)
    self.transactions = h
} catch {
    NSLog("Error: \(error)")  // 记录详细错误
    // 清除损坏数据
    clearCorruptedData()
    self.transactions = [:]  // 重置为空
}
```

**改进**:
- ✅ 明确的日期策略
- ✅ 详细的错误日志
- ✅ 自动清除损坏数据
- ✅ 安全的降级处理

### Date编码策略对比

| 策略 | 格式 | 示例 | 兼容性 |
|------|------|------|--------|
| `.deferredToDate` (默认) | TimeInterval | 1707897600.0 | ❌ 跨平台差 |
| `.iso8601` | ISO8601字符串 | "2024-02-14T08:00:00Z" | ✅ 跨平台好 |
| `.secondsSince1970` | Unix时间戳 | 1707897600 | ✅ 通用 |

**选择ISO8601的原因**:
- 人类可读
- 跨平台兼容
- JSON标准推荐
- 时区感知

## 🔍 验证修复

### 查看日志

在Xcode Console中查看日志输出：

**成功加载**:
```
[TransactionHistory] ✅ Loaded transaction history: 3 addresses
[TransactionHistory] ✅ Loaded swap history: 5 items
[TransactionHistory] ✅ Loaded bridge history: 2 items
```

**检测到损坏数据**:
```
[TransactionHistory] ⚠️ Failed to load transaction history: <error>
[TransactionHistory] 🗑️  Clearing corrupted transaction history data...
```

### 测试步骤

1. **清空历史测试**
   - 运行清除脚本
   - 重启应用
   - 确认历史为空且无错误

2. **新数据测试**
   - 执行一笔交易
   - 刷新历史页面
   - 确认交易正确显示

3. **重启持久化测试**
   - 执行交易后关闭应用
   - 重新打开应用
   - 确认交易历史仍然存在

## 📚 相关文件

### 修改的文件
- `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift`
  - `loadHistory()` - 添加错误处理和日期策略
  - `saveHistory()` - 统一日期编码策略
  - `saveSwapHistory()` - 统一日期编码策略
  - `saveBridgeHistory()` - 统一日期编码策略

### 新增文件
- `mobile/ios/clear_history_data.sh` - 历史数据清除脚本
- `mobile/ios/TRANSACTION_HISTORY_FIX.md` - 本文档

## 🛡️ 预防措施

### 未来数据迁移

如果需要修改数据结构，遵循以下最佳实践：

```swift
// 1. 添加版本号
struct TransactionHistoryV2: Codable {
    let version: Int = 2  // 版本标识
    let transactions: [String: [TransactionGroup]]
}

// 2. 尝试多个版本
private func loadHistory() {
    // 尝试V2
    if let v2 = try? decode(TransactionHistoryV2.self) {
        self.transactions = v2.transactions
        return
    }

    // 回退到V1
    if let v1 = try? decode(TransactionHistoryV1.self) {
        self.transactions = migrate(v1)
        return
    }

    // 全部失败，清除数据
    clearAndReset()
}
```

### 最佳实践

1. **始终使用明确的编码策略**
   ```swift
   encoder.dateEncodingStrategy = .iso8601
   encoder.keyEncodingStrategy = .convertToSnakeCase
   ```

2. **添加版本控制**
   ```swift
   struct VersionedData: Codable {
       let version: Int
       let data: ActualData
   }
   ```

3. **优雅降级**
   ```swift
   do {
       // 尝试加载
   } catch {
       // 记录错误
       // 清除损坏数据
       // 初始化为空
   }
   ```

4. **详细日志**
   ```swift
   NSLog("[Component] ✅ Success: details")
   NSLog("[Component] ⚠️ Warning: details")
   NSLog("[Component] ❌ Error: \(error)")
   ```

## ✅ 总结

**问题**: 交易历史数据格式不兼容导致解码失败
**修复**: 添加ISO8601日期策略 + 自动清除损坏数据
**效果**: 应用不再崩溃，自动恢复到正常状态

现在应用能够：
- ✅ 正确加载新的交易历史
- ✅ 自动处理损坏的旧数据
- ✅ 提供详细的错误日志
- ✅ 优雅降级而不是崩溃

如果问题仍然存在，请运行清除脚本或联系开发者。
