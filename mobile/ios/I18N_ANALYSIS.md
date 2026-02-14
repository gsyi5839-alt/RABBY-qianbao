# iOS 本地化完整分析报告

## 📊 当前状态

### ✅ 已完成的工作
- **55个文件** 已使用 `L()` 函数
- **880次** `L()` 调用（静态文本已本地化）
- **2个文件** 使用 `localization.t()`（Settings相关）
- **72次** `localization.t()` 调用

### ❌ 还需处理
- **40个文件** 包含硬编码的动态文本
- **136个** 带插值的 `Text("...")` 需要本地化

## 🔍 问题详解

### 已本地化的（静态文本）✅
```swift
Text(L("NFTs"))                           // ✅
ProgressView(L("Loading NFTs..."))         // ✅
.navigationTitle(L("Settings"))            // ✅
Button(L("Confirm")) { }                   // ✅
```

### 需要本地化的（动态文本）❌
```swift
Text("\(collection.nftCount) items")                              // ❌
Text("Floor: \(floor)")                                           // ❌
Text("Balance: \(currentAccountBalance) ETH")                     // ❌
Text("Nonce #\(tx.nonce)")                                        // ❌
Text("\(tx.confirmations.count)/\(tx.confirmationsRequired) confirmations")  // ❌
```

## 💡 解决方案

### 方案A：使用 localization.t() 带参数

```swift
// 修改前
Text("\(collection.nftCount) items")

// 修改后
Text(localization.t("mobile.items_count", args: ["count": "\(collection.nftCount)"]))

// JSON中添加
{
  "mobile.items_count": "{{count}} items",
  "mobile.items_count.zh-CN": "{{count}} 项"
}
```

### 方案B：使用 String interpolation + localized

```swift
// 修改前
Text("Floor: \(floor)")

// 修改后
Text("mobile.floor_price".localized(with: ["price": floor]))

// 或
Text(localization.t("mobile.floor_price", args: ["price": floor]))

// JSON中
{
  "mobile.floor_price": "Floor: {{price}}",
  "mobile.floor_price.zh-CN": "地板价: {{price}}"
}
```

## 📋 需要本地化的具体文本列表

### 1. NFT相关 (NFTView.swift)
```swift
Text("\(collection.nftCount) items")       → mobile.nft_items_count
Text("Floor: \(floor)")                    → mobile.nft_floor_price
Text("x\(amount)")                         → mobile.nft_amount
```

### 2. Gnosis Queue (GnosisQueueView.swift)
```swift
Text("\(viewModel.transactions.count) tx")                        → mobile.gnosis_tx_count
Text("\(viewModel.messages.count) msg")                           → mobile.gnosis_msg_count
Text("Nonce #\(tx.nonce)")                                         → mobile.gnosis_nonce
Text("To: \(tx.to.prefix(10))...")                                 → mobile.gnosis_to_address
Text("Value: \(ethValue) ETH")                                     → mobile.gnosis_value_eth
Text("\(tx.confirmations.count)/\(tx.confirmationsRequired) confirmations")  → mobile.gnosis_confirmations_status
```

### 3. DApp Browser (DAppConnectSheet.swift, DAppSearchView.swift)
```swift
Text("Balance: \(currentAccountBalance) ETH")   → mobile.dapp_balance_eth
Text("\(account.balance ?? "0.00") ETH")        → mobile.account_balance_eth
Text("Go to \(url)")                             → mobile.dapp_go_to_url
```

### 4. Settings (SettingsView.swift)
```swift
Text("Revoke \(target.tokenSymbol) approval for \(target.spenderName)?")  → mobile.settings_revoke_approval
Text("Estimated gas: \(gas)")                                             → mobile.settings_estimated_gas
Text("\(selectedForRevoke.count) selected")                               → mobile.settings_selected_count
Text("Revoking \(batchRevokeProgress)/\(batchRevokeTotal)...")           → mobile.settings_revoking_progress
Text("\(latency)ms")                                                      → mobile.settings_latency_ms
Text("Chain ID: \(testnet.id)")                                           → mobile.settings_chain_id
```

### 5. Bridge (BridgeView.swift, BridgeAggregatorSheet.swift)
```swift
Text("Your bridge transaction has been sent. Track the cross-chain transfer in the bridge status section below.\n\nTx: \(txHash ?? "")")  → mobile.bridge_tx_sent
Text("Fee: \(quote.bridgeFee)")                  → mobile.bridge_fee
```

### 6. Clear Pending (ClearPendingView.swift)
```swift
Text("Nonce #\(tx.nonce)")                       → mobile.clear_pending_nonce
Text("To: \(EthereumUtil.truncateAddress(tx.to))")  → mobile.clear_pending_to
Text("Clearing \(clearProgress)/\(pendingTxs.count)...")  → mobile.clear_pending_progress
Text("Clear All Pending (\(pendingTxs.count))")  → mobile.clear_all_pending_count
```

## 🚀 自动化处理脚本

我已经创建了 `process_dynamic_i18n.rb` 脚本来：

1. ✅ 扫描所有136个动态文本
2. ✅ 识别模式并生成合适的key
3. ✅ 自动替换为 `localization.t(key, args: [...])`
4. ✅ 生成所有15种语言的JSON翻译（英文自动填充，其他标记[TODO]）
5. ✅ 生成详细的处理报告

### 使用方法

```bash
cd mobile/ios

# 1. 预览模式（不修改文件）
ruby process_dynamic_i18n.rb --dry-run

# 2. 实际处理
ruby process_dynamic_i18n.rb

# 3. 查看修改
git diff
```

## 📝 处理后需要做的

1. **翻译非英文key**
   - 搜索所有 `[TODO]` 标记
   - 翻译为对应语言
   - 可参考浏览器扩展的翻译

2. **测试验证**
   - 编译运行应用
   - 切换不同语言
   - 验证所有动态文本正确显示

3. **代码审查**
   - 检查参数名是否合理
   - 确认翻译key命名规范
   - 验证所有插值正确

## 💡 翻译示例（中文）

```json
{
  "mobile.nft_items_count": "{{count}} 项",
  "mobile.nft_floor_price": "地板价: {{price}}",
  "mobile.gnosis_tx_count": "{{count}} 笔交易",
  "mobile.gnosis_msg_count": "{{count}} 条消息",
  "mobile.gnosis_nonce": "Nonce #{{nonce}}",
  "mobile.gnosis_to_address": "接收地址: {{address}}",
  "mobile.gnosis_value_eth": "金额: {{value}} ETH",
  "mobile.gnosis_confirmations_status": "{{current}}/{{required}} 个确认",
  "mobile.dapp_balance_eth": "余额: {{balance}} ETH",
  "mobile.dapp_go_to_url": "前往 {{url}}",
  "mobile.settings_revoke_approval": "撤销 {{symbol}} 对 {{spender}} 的授权？",
  "mobile.settings_estimated_gas": "预估Gas: {{gas}}",
  "mobile.settings_selected_count": "已选择 {{count}} 项",
  "mobile.settings_revoking_progress": "正在撤销 {{current}}/{{total}}...",
  "mobile.settings_latency_ms": "{{latency}}毫秒",
  "mobile.settings_chain_id": "链ID: {{id}}",
  "mobile.bridge_fee": "手续费: {{fee}}",
  "mobile.clear_pending_nonce": "Nonce #{{nonce}}",
  "mobile.clear_pending_to": "接收地址: {{address}}",
  "mobile.clear_pending_progress": "清除中 {{current}}/{{total}}...",
  "mobile.clear_all_pending_count": "清除所有待处理 ({{count}})"
}
```

## 🎯 预期效果

完成后：
- ✅ 所有1016个文本（880静态 + 136动态）完全本地化
- ✅ 支持15种语言实时切换
- ✅ 动态内容（金额、地址、数量等）正确显示本地化文本
- ✅ 无需重启应用即可切换语言
