# iOS 多语言本地化 - 完整解决方案

## 📊 现状总结

### ✅ 已完成（大部分工作已做好）
- **静态文本**：880个已使用 `L()` 函数本地化 ✅
- **翻译文件**：15种语言，3500+个key ✅
- **基础设施**：LocalizationManager 完善 ✅

### ❌ 待完成（剩余工作）
- **动态文本**：97个包含变量插值的文本需要本地化 ❌
  - 例如：`Text("\(count) items")`, `Text("Balance: \(amount) ETH")`

## 🎯 问题示例

### 当前代码（未本地化）
```swift
// ❌ 切换语言不会翻译
Text("\(collection.nftCount) items")
Text("Balance: \(currentAccountBalance) ETH")
Text("Nonce #\(tx.nonce)")
```

### 期望效果（本地化后）
```swift
// ✅ 支持多语言
Text(localization.t("mobile.nft_items_count", args: ["count": "\(collection.nftCount)"]))
// 英文: "5 items"
// 中文: "5 项"
// 日文: "5 アイテム"
```

## 🚀 一键解决方案

我已经创建了 **3个自动化脚本** 和 **完整文档**：

### 📄 文档文件

1. **I18N_ANALYSIS.md** - 详细分析报告
   - 当前状态分析
   - 具体文本列表（97个）
   - 翻译示例（中文）

2. **BATCH_LOCALIZATION_GUIDE.md** - 批量处理指南
   - 使用方法
   - 常见问题
   - 验证步骤

### 🤖 自动化脚本

1. **smart_localize.rb** - 处理静态文本（已完成大部分，不需要用）

2. **process_dynamic_i18n.rb** ⭐ **主要使用这个**
   - 扫描97个动态文本
   - 自动生成翻译key
   - 替换为 `localization.t()` 调用
   - 更新所有15个语言的JSON文件

3. **batch_localize.rb** - 旧版脚本（备用）

## 📝 使用步骤

### 第1步：预览（不修改文件）

```bash
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios

# 预览模式 - 查看会做什么改动
ruby process_dynamic_i18n.rb --dry-run
```

**输出示例：**
```
🔍 扫描动态文本...
  ✓ 找到 97 个动态文本

🔨 生成翻译key...
  ✓ 生成了 97 个翻译key

📝 新增的翻译key（前15个）:
  "mobile.nftview_x_items": "{{count}} items"
  "mobile.dappconnectsheet_balance_x_eth": "Balance: {{balance}} ETH"
  "mobile.gnosisqueueview_nonce_x": "Nonce #{{nonce}}"
  ...
```

### 第2步：备份代码

```bash
git add .
git commit -m "Backup before dynamic i18n processing"
```

### 第3步：执行处理

```bash
# 实际处理 - 会修改文件
ruby process_dynamic_i18n.rb
```

**会自动完成：**
- ✅ 注入 `@EnvironmentObject var localization`（如果缺失）
- ✅ 将 97个动态文本替换为 `localization.t()` 调用
- ✅ 在所有15个语言的JSON文件中添加新key
- ✅ 英文自动填充，其他语言标记 `[TODO]`

### 第4步：查看修改

```bash
git diff
```

**示例修改：**
```diff
- Text("\(collection.nftCount) items")
+ Text(localization.t("mobile.nftview_items_count", args: ["count": "\(collection.nftCount)"]))
```

**JSON文件：**
```diff
+ "mobile.nftview_items_count": "{{count}} items"  // en.json
+ "mobile.nftview_items_count": "[TODO] {{count}} items"  // zh-CN.json
```

### 第5步：翻译其他语言

```bash
# 查找所有待翻译项
grep -r "\[TODO\]" RabbyMobile/locales/

# 手动翻译为对应语言
```

**翻译参考（见 I18N_ANALYSIS.md）：**
```json
// zh-CN.json
{
  "mobile.nftview_items_count": "{{count}} 项",
  "mobile.dappconnectsheet_balance_x_eth": "余额: {{balance}} ETH",
  "mobile.gnosisqueueview_nonce_x": "Nonce #{{nonce}}",
  "mobile.gnosisqueueview_confirmations": "{{current}}/{{required}} 个确认"
}
```

### 第6步：测试验证

```bash
# 编译运行
./build_and_run.sh

# 或用Xcode
open RabbyMobile.xcworkspace
```

**测试检查点：**
- ✅ 应用正常编译
- ✅ 切换语言到中文，动态文本正确显示中文
- ✅ 所有数字、金额、地址正确插值
- ✅ 没有显示 `[TODO]` 或 `mobile.xxx` 这样的key

### 第7步：提交更改

```bash
git add .
git commit -m "Complete iOS dynamic text localization for all 97 texts"
```

## 📋 需要翻译的具体内容

### NFT相关（3个）
```json
{
  "mobile.nftgalleryview_x": "#{{innerid}}",
  "mobile.nftgalleryview_token_id_x": "Token ID: #{{innerid}}",
  "mobile.chainbalanceview_x_tokens": "{{count}} tokens"
}
```

**中文：**
```json
{
  "mobile.nftgalleryview_x": "#{{innerid}}",
  "mobile.nftgalleryview_token_id_x": "代币ID: #{{innerid}}",
  "mobile.chainbalanceview_x_tokens": "{{count}} 个代币"
}
```

### Gnosis相关（10+个）
```json
{
  "mobile.gnosisqueueview_nonce_x": "Nonce #{{nonce}}",
  "mobile.gnosisqueueview_to_x": "To: {{address}}",
  "mobile.gnosisqueueview_value_x_eth": "Value: {{value}} ETH"
}
```

**中文：**
```json
{
  "mobile.gnosisqueueview_nonce_x": "Nonce #{{nonce}}",
  "mobile.gnosisqueueview_to_x": "接收地址: {{address}}",
  "mobile.gnosisqueueview_value_x_eth": "金额: {{value}} ETH"
}
```

### DApp相关（5+个）
```json
{
  "mobile.dappconnectsheet_balance_x_eth": "Balance: {{balance}} ETH",
  "mobile.dappsearchview_go_to_x": "Go to {{url}}"
}
```

**中文：**
```json
{
  "mobile.dappconnectsheet_balance_x_eth": "余额: {{balance}} ETH",
  "mobile.dappsearchview_go_to_x": "前往 {{url}}"
}
```

## 💡 常见问题

### Q1: 为什么有些文本没有被处理？
A: 脚本只处理包含插值 `\(...)` 的动态文本。静态文本（如 `Text("Send")`）已经使用 `L()` 函数本地化了。

### Q2: 如果脚本生成的key不合理怎么办？
A: 可以手动修改：
1. 在代码中修改key名称
2. 在所有15个JSON文件中相应修改key
3. 保持key的一致性

### Q3: 翻译可以自动完成吗？
A: 可以参考浏览器扩展的翻译文件（`src/locales/`），很多术语已经翻译过了。

### Q4: 如何回滚？
A: 在运行脚本前已经备份，随时可以回滚：
```bash
git reset --hard HEAD
```

## ✅ 最终效果

完成后：
- **1016个文本** 全部本地化（880静态 + 97动态 + 39已处理）
- **15种语言** 实时切换
- **无需重启** 应用即可切换语言
- **动态内容** 正确显示（金额、数量、地址等）

## 📞 需要帮助？

如果遇到问题：
1. 查看 `I18N_ANALYSIS.md` 了解详情
2. 查看 `BATCH_LOCALIZATION_GUIDE.md` 了解具体用法
3. 运行 `--dry-run` 预览模式先确认
4. 记得备份代码再处理

---

🎉 **准备好了吗？运行脚本开始自动化处理！**

```bash
cd mobile/ios
ruby process_dynamic_i18n.rb --dry-run  # 先预览
ruby process_dynamic_i18n.rb             # 实际处理
```
