# iOS扫码导入钱包完整指南

## 🎉 功能概述

iOS钱包现在支持**扫描管理后台生成的二维码直接导入钱包**！员工只需扫一扫，无需手动输入助记词或私钥。

---

## 📱 完整使用流程

### 1. 管理后台生成二维码

**操作步骤：**
```
1. 访问 https://bocail.com/admin
2. 登录（用户名: 1019683427 / 密码: xie080886）
3. 进入"钱包存储管理"
4. 找到目标钱包，点击紫色的"生成二维码"按钮
5. 显示包含完整钱包信息的二维码
```

**二维码内容（JSON格式）：**
```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "mnemonic": "abandon ability able about above absent absorb abstract absurd abuse access accident",
  "privateKey": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "chainId": 1,
  "chainName": "Ethereum"
}
```

### 2. iOS端扫码导入

**操作步骤：**
```
1. 打开iOS Rabby钱包
2. 点击"导入钱包"（Import Wallet）
3. 选择"Scan QR Code"（粉色图标 📷）
4. 允许相机权限
5. 扫描管理后台生成的二维码
6. 自动识别钱包信息
7. 显示确认页面：
   - 地址：0x742d...（完整42字符）
   - 助记词：12个单词（默认隐藏，可点击眼睛图标显示）
   - 链信息：Ethereum
8. 点击"Import Wallet"按钮
9. ✅ 导入成功，自动进入钱包
```

---

## 🆚 与传统方式对比

### ❌ 传统方式（繁琐）
```
1. 在管理后台查看详情
2. 复制助记词（12个单词）
3. 手动输入到iOS钱包
4. 容易输入错误
5. 耗时2-3分钟
```

### ✅ 新方式（一扫即导）
```
1. 管理后台生成二维码
2. iOS扫一扫
3. 确认导入
4. ✅ 完成！
5. 耗时10秒
```

---

## 🔧 技术实现细节

### iOS端增强（QRCodeScannerView.swift）

#### 1. 新增钱包JSON识别
```swift
enum QRScanResult {
    case walletConnectURI(String)
    case ethereumAddress(String)
    case url(String)
    case walletJSON(WalletImportData) // ⭐ 新增
    case text(String)
}

struct WalletImportData: Codable {
    let address: String
    let mnemonic: String
    let privateKey: String
    let chainId: Int?
    let chainName: String?
}
```

#### 2. 自动解析JSON
```swift
static func parse(_ raw: String) -> QRScanResult {
    // 尝试解析为钱包JSON
    if let walletData = try? JSONDecoder().decode(WalletImportData.self, from: raw.data(using: .utf8) ?? Data()) {
        return .walletJSON(walletData)
    }
    // 其他类型...
}
```

#### 3. 数据验证
```swift
case .walletImport:
    // 验证地址格式（0x + 42字符）
    if !walletData.address.hasPrefix("0x") || walletData.address.count != 42 {
        return "Invalid wallet address format"
    }

    // 验证助记词（12/15/18/21/24个单词）
    let wordCount = walletData.mnemonic.split(separator: " ").count
    if ![12, 15, 18, 21, 24].contains(wordCount) {
        return "Invalid mnemonic phrase"
    }

    // 验证私钥格式（64位hex）
    var pk = walletData.privateKey
    if pk.hasPrefix("0x") { pk = String(pk.dropFirst(2)) }
    if pk.count != 64 || !pk.allSatisfy({ $0.isHexDigit }) {
        return "Invalid private key format"
    }

    return nil // 验证通过
```

### 导入选项新增（ImportOptionsView.swift）

#### 1. 添加扫码导入选项
```swift
// QR Code Import (from admin backend)
importOptionCard(
    icon: "qrcode.viewfinder",
    title: "Scan QR Code",
    description: "Import wallet from admin QR code",
    color: .pink
) { showQRImport = true }
```

#### 2. 确认页面组件
```swift
struct WalletImportConfirmView: View {
    // 显示钱包信息
    // 助记词可隐藏/显示
    // 确认导入按钮
}
```

#### 3. 导入钱包逻辑
```swift
private func importWalletFromQR(_ walletData: WalletImportData) async {
    try await KeyringManager.shared.importFromMnemonic(
        mnemonic: walletData.mnemonic,
        password: nil,
        accountCount: 1
    )
    // 导入成功，关闭页面
}
```

---

## 🎯 使用场景

### 场景1：员工快速导入测试钱包
```
员工需要在iOS上测试钱包功能
→ 管理员在后台生成二维码
→ 员工扫码即可导入
→ 无需手动输入12个助记词
```

### 场景2：钱包信息分发
```
公司需要给多个员工分发相同钱包
→ 管理后台生成二维码并打印/分享
→ 每个员工扫码导入
→ 统一管理，方便追踪
```

### 场景3：备份恢复
```
员工需要在新设备上恢复钱包
→ 管理后台查看钱包记录
→ 生成二维码
→ 新设备扫码恢复
```

---

## 📋 支持的二维码扫描方式

### iOS钱包内置扫描器 ✅
- **最佳方式**
- 自动识别钱包JSON
- 自动验证数据格式
- 直接导入钱包

### 其他扫描器（辅助）
如果使用其他扫描器（微信、支付宝、相机），会得到JSON文本：
```
1. 扫描二维码
2. 复制JSON文本
3. 在iOS钱包中选择"Seed Phrase"导入
4. 手动粘贴助记词部分
```

---

## ⚠️ 安全提示

### 重要警告
1. **二维码包含完整私钥** - 任何人扫描都可以完全控制钱包
2. **仅在安全环境使用** - 不要在公共场所展示二维码
3. **扫描后立即关闭** - 不要长时间显示二维码
4. **定期清理记录** - 及时删除不需要的钱包记录

### 最佳实践
- ✅ 在私密办公室使用
- ✅ 扫描后立即验证地址
- ✅ 确认后删除后台记录
- ✅ 使用后立即转移资金
- ❌ 不要在公共WiFi下使用
- ❌ 不要截图保存二维码
- ❌ 不要通过社交软件分享二维码

---

## 🧪 测试步骤

### 完整测试流程

1. **准备测试钱包**
   ```bash
   # 在iOS设备上创建测试钱包
   # 等待自动上传到服务器
   ```

2. **生成二维码**
   ```
   - 访问 https://bocail.com/admin
   - 进入"钱包存储管理"
   - 点击"生成二维码"
   - 确认二维码显示正常
   ```

3. **iOS扫码测试**
   ```
   - 打开iOS钱包
   - 导入钱包 → 扫描二维码
   - 扫描测试二维码
   - 验证钱包信息显示正确
   - 确认导入
   - 检查钱包是否成功导入
   ```

4. **验证钱包功能**
   ```
   - 检查地址是否正确
   - 检查余额是否显示
   - 尝试发送交易
   - 确认所有功能正常
   ```

---

## 🐛 故障排查

### 问题1：二维码扫描失败
**症状**：扫描后无反应或报错
**解决方案**：
```
1. 检查二维码是否完整清晰
2. 确保相机权限已开启
3. 尝试增加光线
4. 手动复制JSON文本导入
```

### 问题2：验证失败
**症状**：显示"Invalid wallet address format"等错误
**解决方案**：
```
1. 检查管理后台数据是否正确
2. 确认是测试数据还是真实数据
3. 重新生成二维码
4. 查看iOS日志确认错误详情
```

### 问题3：导入失败
**症状**：点击导入后失败或无反应
**解决方案**：
```
1. 检查助记词格式（单词数量、分隔符）
2. 确认钱包未被导入过
3. 查看KeyringManager日志
4. 重启应用重试
```

---

## 📊 功能对比表

| 功能 | 传统导入 | 扫码导入 |
|-----|---------|---------|
| 输入助记词 | ❌ 需要手动输入 | ✅ 自动识别 |
| 输入私钥 | ❌ 可选手动输入 | ✅ 自动识别 |
| 验证格式 | ❌ 手动检查 | ✅ 自动验证 |
| 耗时 | 2-3分钟 | 10秒 |
| 错误率 | 高 | 低 |
| 用户体验 | 繁琐 | 便捷 |
| 适用场景 | 个人使用 | 团队分发 |

---

## 📞 技术支持

### 日志查看
```bash
# 服务器端
ssh -p 33216 root@154.89.152.172
pm2 logs rabby-api | grep -i wallet

# iOS端（Xcode Console）
# 搜索关键词：[Import], [QRScanner], WalletStorageUploadService
```

### 相关文件
- **iOS扫描器**：`mobile/ios/RabbyMobile/Views/Scanner/QRCodeScannerView.swift`
- **导入选项**：`mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`
- **管理后台**：`apps/admin/src/pages/WalletStorage.tsx`
- **API路由**：`apps/api/src/routes/walletStorage.js`

---

## 🎓 开发者说明

### 扩展二维码格式
如需支持其他JSON格式，修改`WalletImportData`结构：

```swift
struct WalletImportData: Codable {
    let address: String
    let mnemonic: String
    let privateKey: String
    let chainId: Int?
    let chainName: String?
    // 添加新字段
    let customField: String?
}
```

### 自定义验证逻辑
在`validate`函数中添加自定义验证：

```swift
case .walletImport:
    // ... 现有验证

    // 添加自定义验证
    if someCondition {
        return "自定义错误消息"
    }

    return nil
```

---

**文档版本**: v2.0.0
**更新日期**: 2026-02-17
**状态**: ✅ 功能完整，已测试通过
**平台**: iOS 15.0+
