# iOS 批量本地化指南

## 问题描述

目前iOS应用中有大量页面/组件使用 `Text("...")` 硬编码，即使语言切换功能正常也不会自动翻译。需要批量将硬编码替换成 `localization.t(key)` 并补齐各语言的翻译key。

**当前状态：**
- 57个Swift视图文件
- 136处硬编码 `Text("...")`
- 只有SettingsView完成了本地化
- 已有15种语言的JSON翻译文件

## 自动化解决方案

### 方案1：使用增强版批量处理脚本（推荐）

创建了 `batch_localize.rb` 脚本，自动完成：

1. ✅ 自动注入 `@EnvironmentObject var localization: LocalizationManager`
2. ✅ 扫描并提取所有硬编码文本
3. ✅ 智能生成翻译key（如 "Send Token" → "send_token"）
4. ✅ 替换 `Text("...")` 为 `Text(localization.t("key"))`
5. ✅ 自动更新所有15种语言的JSON文件
6. ✅ 生成详细的处理报告

**使用方法：**

```bash
cd mobile/ios
ruby batch_localize.rb
```

**脚本功能：**
- 跳过动态内容（包含变量插值的文本）
- 跳过空字符串和纯数字
- 自动去重，避免重复key
- 英文翻译自动填充，其他语言标记为 `[TODO]` 待翻译
- 保持JSON文件格式整洁（按字母排序）

**输出示例：**
```
🚀 开始批量本地化处理...
============================================================
✓ 加载 en.json (1234 keys)
✓ 加载 zh-CN.json (1234 keys)
...

📝 扫描硬编码文本...
找到 95 个唯一硬编码文本

🔧 处理视图文件...
  ✅ AssetsView.swift
  ✅ SwapView.swift
  ✅ BridgeView.swift
  ...

📚 更新翻译文件...
新增 95 个翻译key
  ✓ en.json (+95 keys)
  ✓ zh-CN.json (+95 keys)
  ...

============================================================
📊 处理统计：
  • 处理文件数: 45
  • 新增翻译key: 95
  • 替换次数: 136
============================================================

⚠️  注意：
  非英文语言文件中的新key需要人工翻译
  请搜索 '[TODO]' 标记并替换为正确的翻译
```

### 方案2：手动处理（针对特殊情况）

对于包含复杂逻辑的视图，可能需要手动处理：

#### 步骤1：注入LocalizationManager

```swift
struct YourView: View {
    @EnvironmentObject var localization: LocalizationManager  // ← 添加这行

    var body: some View {
        // ...
    }
}
```

#### 步骤2：替换硬编码文本

**简单文本：**
```swift
// 修改前
Text("Send")

// 修改后
Text(localization.t("send"))
```

**带参数的文本：**
```swift
// 修改前
Text("Balance: \(amount) ETH")

// 修改后
Text(localization.t("balance_with_amount", args: ["amount": amount, "symbol": "ETH"]))
```

JSON中定义：
```json
{
  "balance_with_amount": "余额: {amount} {symbol}"
}
```

#### 步骤3：添加翻译key

在 `mobile/ios/RabbyMobile/locales/en.json` 中添加：
```json
{
  "send": "Send",
  "receive": "Receive",
  "balance_with_amount": "Balance: {amount} {symbol}"
}
```

在其他14个语言文件中添加对应翻译。

## 翻译key命名规范

1. **全小写，下划线分隔**: `send_token`, `transaction_history`
2. **按功能分组**:
   - `tab_assets`, `tab_swap`, `tab_settings`
   - `swap_from`, `swap_to`, `swap_amount`
   - `settings_account`, `settings_security`
3. **保持简洁明确**: `confirm` 而不是 `confirm_button_label`
4. **动态内容用占位符**: `{amount}`, `{symbol}`, `{chainName}`

## 处理后需要做的工作

### 1. 翻译非英文key

脚本会在所有非英文JSON文件中标记新key为 `[TODO]`：

```json
{
  "send_token": "[TODO] Send Token"
}
```

**处理方法：**

```bash
# 查找所有待翻译项
cd mobile/ios/RabbyMobile/locales
grep -r "\[TODO\]" .

# 手动翻译或使用翻译工具
```

**中文示例：**
```json
{
  "send_token": "发送代币",
  "transaction_history": "交易历史",
  "balance_with_amount": "余额: {amount} {symbol}"
}
```

### 2. 处理动态文本

脚本会跳过包含变量插值的文本，这些需要手动处理：

```swift
// 动态文本（脚本跳过）
Text("Balance: \(balance) ETH")
Text("Nonce #\(nonce)")
Text("\(confirmations)/\(required) confirmations")

// 需要改为
Text(localization.t("balance_with_amount", args: ["balance": balance, "symbol": "ETH"]))
Text(localization.t("nonce_number", args: ["nonce": "\(nonce)"]))
Text(localization.t("confirmations_status", args: [
    "current": "\(confirmations)",
    "required": "\(required)"
]))
```

### 3. 特殊组件本地化

**Section 标题：**
```swift
Section(localization.t("settings_account")) {
    // ...
}
```

**NavigationTitle：**
```swift
.navigationTitle(localization.t("tab_settings"))
```

**Alert：**
```swift
.alert(localization.t("error"), isPresented: $showError) {
    Button(localization.t("ok")) { }
}
```

**Picker：**
```swift
Picker(localization.t("select_chain"), selection: $selectedChain) {
    // ...
}
```

## 验证本地化效果

1. **编译测试：**
```bash
cd mobile/ios
./build_and_run.sh
```

2. **切换语言测试：**
   - 在应用设置中切换语言
   - 验证所有文本是否正确切换
   - 检查是否有遗漏的硬编码

3. **检查缺失翻译：**
```bash
# 在应用中查找显示为key而不是文本的地方
# 这表示该key在当前语言的JSON文件中不存在
```

## 翻译资源

可以参考扩展钱包的翻译文件：
- `src/locales/` 目录下的各语言JSON文件
- 已经包含了大部分常用术语的翻译

## 进度追踪

创建一个待本地化文件清单：

- [ ] AssetsView.swift
- [ ] SwapView.swift
- [ ] BridgeView.swift
- [ ] NFTView.swift
- [ ] HistoryView.swift
- [ ] DAppBrowserView.swift
- [ ] TransactionApprovalView.swift
- [ ] SendTokenView.swift
- [ ] CreateWalletView.swift
- [ ] ImportWalletView.swift
- [x] SettingsView.swift（已完成）
- ... （其他文件）

## 常见问题

**Q: 为什么要跳过动态文本？**
A: 包含变量的文本需要使用参数化翻译（args），需要手动处理以确保正确。

**Q: 如何处理复数形式？**
A: 在翻译key中使用不同的key，如 `item_singular` 和 `item_plural`。

**Q: 脚本会覆盖已有的翻译吗？**
A: 不会。脚本只添加新key，不修改已存在的翻译。

**Q: 如何回滚？**
A: 在运行脚本前，建议先提交git，这样可以随时回滚：
```bash
git add .
git commit -m "Backup before batch localization"
ruby batch_localize.rb
# 如果有问题
git reset --hard HEAD
```

## 推荐工作流程

1. **备份代码**
```bash
git add .
git commit -m "Before batch localization"
```

2. **运行脚本**
```bash
cd mobile/ios
ruby batch_localize.rb
```

3. **检查生成的修改**
```bash
git diff
```

4. **翻译非英文key**
   - 搜索所有 `[TODO]` 标记
   - 手动翻译或使用翻译工具
   - 可参考扩展钱包的翻译文件

5. **处理动态文本**
   - 搜索代码中剩余的 `Text("\(...)")`
   - 手动改为参数化翻译

6. **测试验证**
   - 编译运行
   - 切换不同语言测试
   - 修复任何问题

7. **提交更改**
```bash
git add .
git commit -m "Complete iOS localization for all views"
```
