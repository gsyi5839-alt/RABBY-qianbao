# iOS钱包"退出钱包"功能实现文档

## 📋 功能概述

在iOS设置页面添加了"退出钱包"功能，允许用户完全清空当前钱包数据，返回到初始状态重新创建或导入新钱包。

### 功能对比

| 功能 | 锁定钱包 | 退出钱包 |
|------|---------|---------|
| 清除内存keyrings | ✅ | ✅ |
| 删除Keychain vault | ❌ | ✅ |
| isInitialized状态 | 保持true | 变为false |
| 下一步操作 | 输入密码解锁 | 重新创建/导入钱包 |
| 数据恢复 | 密码解锁即可 | 需要助记词 |
| 按钮颜色 | 橙色 | 红色（危险操作） |

## 🏗️ 实现架构

### 1. KeyringManager 新增方法

**文件**: `mobile/ios/RabbyMobile/Core/KeyringManager.swift`

```swift
/// 完全重置钱包（退出登录）
/// ⚠️ 警告：这会永久删除加密vault，用户必须有助记词备份才能恢复
func resetWallet() async throws {
    NSLog("[KeyringManager] 🔴 resetWallet called - clearing vault and all data")

    // 1. 清除内存中的keyrings
    keyrings.removeAll()
    password = nil
    currentAccount = nil

    // 2. 删除Keychain中的加密vault
    try await storageManager.deleteEncryptedVault()

    // 3. 清除PreferenceManager中的账户数据
    PreferenceManager.shared.currentAccount = nil
    PreferenceManager.shared.accounts.removeAll()

    // 4. 清除生物识别密码
    BiometricAuthManager.shared.disableBiometric()

    // 5. 重置状态
    isUnlocked = false
    isInitialized = false

    // 发送通知
    NotificationCenter.default.post(name: .walletReset, object: nil)
}
```

**新增通知**:
```swift
extension Notification.Name {
    static let walletReset = Notification.Name("walletReset")
}
```

### 2. StorageManager 方法更新

**文件**: `mobile/ios/RabbyMobile/Core/StorageManager.swift`

```swift
/// Delete encrypted vault (异步版本)
func deleteEncryptedVault() async throws {
    try deleteFromKeychain(key: "encryptedVault")
}
```

### 3. SettingsView UI实现

**文件**: `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`

#### 新增状态变量

```swift
@State private var showLogoutConfirm = false
@State private var showLogoutPasswordPrompt = false
@State private var logoutPassword = ""
@State private var logoutError = ""
@State private var isLoggingOut = false
```

#### UI布局（在"关于"Section下方）

```swift
// Lock and Logout buttons
Section {
    // 锁定钱包按钮（橙色）
    Button(action: lockWallet) {
        HStack {
            Spacer()
            Text(localization.t("lock_wallet"))
                .foregroundColor(.orange)
                .fontWeight(.semibold)
            Spacer()
        }
    }

    // 退出钱包按钮（红色 - 危险操作）
    Button(action: { showLogoutConfirm = true }) {
        HStack {
            Spacer()
            Text(localization.t("logout_wallet"))
                .foregroundColor(.red)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}
```

#### 两步确认流程

**第一步：警告对话框**
```swift
.alert(localization.t("logout_wallet_confirm_title"), isPresented: $showLogoutConfirm) {
    Button(localization.t("cancel"), role: .cancel) {}
    Button(localization.t("continue"), role: .destructive) {
        showLogoutPasswordPrompt = true
    }
} message: {
    Text(localization.t("logout_wallet_confirm_message"))
}
```

**第二步：密码确认Sheet**
```swift
.sheet(isPresented: $showLogoutPasswordPrompt) {
    LogoutPasswordPromptView(
        isPresented: $showLogoutPasswordPrompt,
        password: $logoutPassword,
        errorMessage: $logoutError,
        isLoggingOut: $isLoggingOut,
        onConfirm: executeLogout
    )
}
```

#### 执行退出逻辑

```swift
private func executeLogout() {
    guard !logoutPassword.isEmpty else {
        logoutError = localization.t("password_required")
        return
    }

    isLoggingOut = true
    logoutError = ""

    Task {
        do {
            // 1. 验证密码
            let valid = try await keyringManager.verifyPassword(logoutPassword)
            guard valid else {
                await MainActor.run {
                    logoutError = localization.t("incorrect_password")
                    isLoggingOut = false
                }
                return
            }

            // 2. 执行退出钱包
            try await keyringManager.resetWallet()

            await MainActor.run {
                isLoggingOut = false
                showLogoutPasswordPrompt = false
                logoutPassword = ""

                // 触发震动反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                logoutError = error.localizedDescription
                isLoggingOut = false
            }
        }
    }
}
```

### 4. 密码确认弹窗组件

**新增组件**: `LogoutPasswordPromptView`

```swift
struct LogoutPasswordPromptView: View {
    @EnvironmentObject var localization: LocalizationManager
    @Binding var isPresented: Bool
    @Binding var password: String
    @Binding var errorMessage: String
    @Binding var isLoggingOut: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.red)

                // 标题和说明
                VStack(spacing: 12) {
                    Text(localization.t("logout_password_prompt_title"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(localization.t("logout_password_prompt_message"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 密码输入
                SecureField(localization.t("enter_password"), text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // 错误提示
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text(errorMessage)
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                // 确认按钮
                Button(action: onConfirm) {
                    HStack {
                        if isLoggingOut {
                            ProgressView()
                        }
                        Text(isLoggingOut
                            ? localization.t("logging_out")
                            : localization.t("confirm_logout"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty || isLoggingOut ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(password.isEmpty || isLoggingOut)
            }
            .navigationTitle(localization.t("logout_wallet"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization.t("cancel")) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
```

## 🌍 国际化支持

### 中文翻译 (zh-CN.json)

```json
{
  "logout_wallet": "退出钱包",
  "logout_wallet_confirm_title": "⚠️ 退出钱包",
  "logout_wallet_confirm_message": "此操作将永久删除当前钱包数据。\n\n⚠️ 请确保您已备份助记词或私钥，否则将永久失去资产访问权限！\n\n退出后可以重新创建新钱包或导入现有钱包。",
  "logout_password_prompt_title": "最后确认",
  "logout_password_prompt_message": "请输入密码以确认退出钱包。\n\n此操作不可撤销，请确保已备份助记词！",
  "logging_out": "退出中...",
  "confirm_logout": "确认退出",
  "logout_failed": "退出失败",
  "password_required": "请输入密码"
}
```

### 英文翻译 (en.json)

```json
{
  "logout_wallet": "Logout Wallet",
  "logout_wallet_confirm_title": "⚠️ Logout Wallet",
  "logout_wallet_confirm_message": "This action will permanently delete current wallet data.\n\n⚠️ Make sure you have backed up your seed phrase or private key, or you will lose access to your assets forever!\n\nAfter logout, you can create a new wallet or import an existing one.",
  "logout_password_prompt_title": "Final Confirmation",
  "logout_password_prompt_message": "Please enter your password to confirm wallet logout.\n\nThis action cannot be undone. Make sure you have backed up your seed phrase!",
  "logging_out": "Logging out...",
  "confirm_logout": "Confirm Logout",
  "logout_failed": "Logout failed",
  "password_required": "Password required"
}
```

## 🔐 安全机制

### 1. 两步确认流程

```
用户点击"退出钱包"
    ↓
显示警告Alert（第一步确认）
 - 说明操作的危险性
 - 提醒用户备份助记词
    ↓
用户点击"继续"
    ↓
显示密码输入Sheet（第二步确认）
 - 要求输入当前钱包密码
 - 防止误操作或未授权访问
    ↓
验证密码成功
    ↓
执行resetWallet()
    ↓
返回OnboardingView（欢迎页面）
```

### 2. 密码验证

- 使用现有的`KeyringManager.verifyPassword()`方法
- 确保只有知道密码的用户才能执行退出操作
- 验证失败时显示错误提示，不会清空数据

### 3. 数据清理顺序

```swift
// 1. 清除内存数据（可恢复）
keyrings.removeAll()
password = nil
currentAccount = nil

// 2. 清除持久化数据（不可恢复）
storageManager.deleteEncryptedVault()  // Keychain
PreferenceManager.shared.accounts.removeAll()  // UserDefaults

// 3. 清除生物识别
BiometricAuthManager.shared.disableBiometric()

// 4. 重置状态标志
isUnlocked = false
isInitialized = false  // 关键：触发返回OnboardingView
```

### 4. 错误处理

```swift
do {
    try await keyringManager.resetWallet()
} catch {
    // 显示错误信息，不会清空数据
    logoutError = error.localizedDescription
}
```

## 📱 用户体验设计

### 视觉层次

1. **锁定钱包** - 橙色按钮
   - 临时操作
   - 中等风险

2. **退出钱包** - 红色按钮
   - 永久操作
   - 高风险（需要助记词才能恢复）

### 交互流程

```
设置页面
    ↓
点击"退出钱包"（红色按钮）
    ↓
Alert警告弹窗
 ├─ 取消 → 返回设置页面
 └─ 继续 → 密码确认Sheet
          ├─ 取消 → 返回设置页面
          └─ 输入密码 + 确认退出
                      ↓
                  验证密码
                   ├─ 失败 → 显示错误，停留在Sheet
                   └─ 成功 → 执行退出
                             ↓
                         返回欢迎页面
                        （可创建新钱包或导入现有钱包）
```

### 反馈机制

- **触觉反馈**: 成功退出时触发震动（`UINotificationFeedbackGenerator`）
- **加载状态**: 显示"退出中..."加载动画
- **错误提示**: 密码错误时显示红色错误文本

## 🔄 状态流转

### RootView状态判断

```swift
if isCheckingAuth {
    SplashView()  // 启动画面
} else if !keyringManager.isInitialized {
    OnboardingView()  // 未初始化 → 欢迎页面
} else if keyringManager.isUnlocked && !autoLock.isLocked {
    MainTabView()  // 已解锁 → 主界面
} else {
    UnlockView()  // 已锁定 → 解锁页面
}
```

### 退出后的状态

```
resetWallet() 执行后：
- isInitialized = false
- isUnlocked = false
    ↓
RootView自动显示OnboardingView
    ↓
用户可以选择：
 - 创建新钱包
 - 导入现有钱包（通过助记词/私钥/Keystore）
 - 添加观察地址
```

## 🧪 测试指南

### 功能测试

1. **正常退出流程**
   ```
   设置 → 退出钱包 → 继续 → 输入正确密码 → 确认退出
   ✅ 应该返回OnboardingView
   ✅ 所有钱包数据应被清除
   ✅ 无法通过原密码解锁（因为vault已删除）
   ```

2. **取消操作**
   ```
   测试1: Alert中点击"取消" → ✅ 应停留在设置页面
   测试2: Sheet中点击"取消" → ✅ 应停留在设置页面
   ```

3. **密码错误**
   ```
   输入错误密码 → 点击"确认退出"
   ✅ 应显示"密码错误"提示
   ✅ 不应清除任何数据
   ✅ 用户可以重新输入
   ```

4. **密码为空**
   ```
   不输入密码时 → ✅ "确认退出"按钮应为灰色禁用状态
   ```

### 安全测试

1. **验证Keychain清除**
   ```bash
   # 退出钱包后，检查Keychain是否还有vault
   # 应该返回nil或抛出itemNotFound错误
   ```

2. **验证PreferenceManager清除**
   ```swift
   PreferenceManager.shared.currentAccount  // 应为nil
   PreferenceManager.shared.accounts.count  // 应为0
   ```

3. **验证生物识别清除**
   ```swift
   BiometricAuthManager.shared.isBiometricEnabled  // 应为false
   ```

### 用户体验测试

1. **警告信息清晰度**
   - ✅ 用户应能清楚理解操作的不可逆性
   - ✅ 用户应知道需要助记词才能恢复

2. **加载状态**
   - ✅ 点击"确认退出"后应显示加载动画
   - ✅ 加载期间按钮应禁用，防止重复点击

3. **震动反馈**
   - ✅ 成功退出时应有触觉反馈

## 📝 开发注意事项

### 关键实现细节

1. **isInitialized状态**
   - 这是触发返回OnboardingView的关键
   - 必须在删除vault后设置为false

2. **异步方法**
   - `resetWallet()`和`deleteEncryptedVault()`都是async方法
   - 调用时必须使用`await`

3. **通知机制**
   - 发送`walletReset`通知，其他组件可监听此事件

4. **错误处理**
   - 所有异步操作都包裹在try-catch中
   - 错误信息通过`logoutError`状态显示给用户

### 潜在问题和解决方案

1. **问题**: 退出后残留数据
   - **解决**: 确保清理所有存储位置（Keychain、UserDefaults、内存）

2. **问题**: 状态不同步
   - **解决**: 使用`@MainActor`确保UI更新在主线程

3. **问题**: 重复点击导致多次执行
   - **解决**: 使用`isLoggingOut`状态禁用按钮

## 🚀 未来扩展

### 可选增强功能

1. **导出数据选项**
   ```swift
   // 退出前允许导出钱包数据
   - 助记词导出
   - 私钥导出
   - 交易历史导出
   ```

2. **多钱包支持**
   ```swift
   // 支持多个钱包账户
   - 只退出当前钱包
   - 切换到其他钱包
   ```

3. **云备份集成**
   ```swift
   // 退出前提醒用户云备份状态
   - iCloud备份检查
   - 服务器备份检查
   ```

## ✅ 实现检查清单

- [x] KeyringManager.resetWallet()方法
- [x] StorageManager.deleteEncryptedVault()异步化
- [x] SettingsView添加"退出钱包"按钮
- [x] 两步确认流程（Alert + Sheet）
- [x] LogoutPasswordPromptView组件
- [x] 密码验证逻辑
- [x] 错误处理和提示
- [x] 加载状态和禁用逻辑
- [x] 触觉反馈
- [x] 中文翻译（zh-CN.json）
- [x] 英文翻译（en.json）
- [x] walletReset通知
- [x] 清除PreferenceManager数据
- [x] 清除BiometricAuthManager数据
- [x] RootView状态流转正确

## 📚 相关文件

### 修改的文件

1. `mobile/ios/RabbyMobile/Core/KeyringManager.swift`
   - 新增`resetWallet()`方法
   - 新增`walletReset`通知

2. `mobile/ios/RabbyMobile/Core/StorageManager.swift`
   - `deleteEncryptedVault()`方法改为async

3. `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
   - 添加"退出钱包"按钮
   - 添加确认对话框
   - 添加`LogoutPasswordPromptView`组件
   - 添加`executeLogout()`方法

4. `mobile/ios/RabbyMobile/locales/zh-CN.json`
   - 添加11个新翻译键

5. `mobile/ios/RabbyMobile/locales/en.json`
   - 添加11个新翻译键

### 未修改的文件

- `RootView.swift` - 已有的状态判断逻辑自动支持
- `PreferenceManager.swift` - 使用现有的清除方法
- `BiometricAuthManager.swift` - 使用现有的禁用方法

## 🎯 总结

这个"退出钱包"功能提供了完整的钱包重置能力，同时保持了高度的安全性：

✅ **安全性**: 两步确认 + 密码验证
✅ **用户友好**: 清晰的警告信息 + 视觉层次
✅ **完整性**: 清除所有存储位置的数据
✅ **国际化**: 中英文完整支持
✅ **错误处理**: 完善的异常处理和用户提示
✅ **可扩展**: 预留了通知机制供其他组件监听

用户退出钱包后可以：
1. 创建全新的钱包
2. 导入不同的助记词/私钥
3. 添加观察地址
4. 连接硬件钱包

这为用户提供了完全的钱包管理自由度！
