# iOS应用全面本地化指南

## ✅ 当前方案：JSON + LocalizationManager

### 为什么不用iOS原生国际化？

**iOS原生（NSLocalizedString + .strings）的限制**：
- ❌ **无法应用内切换**：必须重启应用才能切换语言
- ❌ **不支持动态刷新**：系统语言锁定在启动时
- ❌ **格式不兼容**：无法与Web版共享翻译文件
- ❌ **配置复杂**：需要在Xcode中为每个语言创建.lproj文件夹

**当前方案的优势**：
- ✅ **实时切换**：用户在应用内选择语言后立即生效
- ✅ **自动刷新**：SwiftUI响应@Published变化自动更新UI
- ✅ **共享翻译**：与Web扩展钱包共享相同的JSON文件
- ✅ **灵活控制**：完全自定义的本地化逻辑

---

## 🎯 本地化实施方案

### 第1步：确保视图注入LocalizationManager

```swift
struct YourView: View {
    @EnvironmentObject var localization: LocalizationManager  // ✅ 必须添加

    var body: some View {
        VStack {
            // 使用翻译
            Text(localization.t("your_key"))
        }
    }
}
```

### 第2步：替换硬编码文本

**替换前**：
```swift
Text("Send")
Text("Transaction Sent")
.navigationTitle("Settings")
Section("Account") { ... }
```

**替换后**：
```swift
Text(localization.t("send"))
Text(localization.t("transaction_sent"))
.navigationTitle(localization.t("tab_settings"))
Section(localization.t("settings_account")) { ... }
```

### 第3步：添加翻译key到locale文件

**en.json**:
```json
{
  "send": "Send",
  "transaction_sent": "Transaction Sent",
  "tab_settings": "Settings",
  "settings_account": "Account"
}
```

**zh-CN.json**:
```json
{
  "send": "发送",
  "transaction_sent": "交易已发送",
  "tab_settings": "设置",
  "settings_account": "账户"
}
```

---

## 📋 需要本地化的页面清单

### ✅ 已完成
- [x] **SettingsView** - 完全本地化（示范）

### ⏳ 待本地化
- [ ] **Dashboard/Assets页面**
- [ ] **Swap页面**
- [ ] **NFT页面**
- [ ] **History页面**
- [ ] **Send/Receive页面**
- [ ] **Bridge页面**
- [ ] **Token Approval页面**
- [ ] **Wallet创建/导入页面**

---

## 🔧 自动化工具

已创建 `localize_views.rb` 脚本用于批量处理：

```bash
cd mobile/ios
ruby localize_views.rb
```

**功能**：
- ✅ 自动注入 `@EnvironmentObject var localization`
- ✅ 替换常见硬编码文本（Send, Cancel, Done等）
- ⚠️ 复杂文本需要手动处理

---

## 🎨 SwiftUI自动刷新机制

### LocalizationManager工作原理

```swift
class LocalizationManager: ObservableObject {
    @Published private(set) var currentLocale: String = "en"
    @Published private(set) var translations: [String: String] = [:]
}
```

**自动刷新流程**：
1. 用户在Settings中选择新语言
2. `PreferenceManager.setLocale()` 发送通知
3. `LocalizationManager` 接收通知并调用 `setLocale()`
4. `@Published` 属性变化触发SwiftUI刷新
5. 所有使用 `@EnvironmentObject` 的视图**自动重新渲染**
6. ✅ **无需重启应用**

### 示例代码

```swift
// App根视图注入
@main
struct RabbyMobileApp: App {
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(localizationManager)  // ✅ 注入到环境
        }
    }
}

// 子视图自动接收
struct AnyChildView: View {
    @EnvironmentObject var localization: LocalizationManager  // ✅ 自动注入

    var body: some View {
        Text(localization.t("hello"))  // ✅ 语言切换时自动刷新
    }
}
```

---

## 📊 当前支持的15种语言

1. 🇬🇧 English (en)
2. 🇨🇳 简体中文 (zh-CN)
3. 🇭🇰 繁體中文 (zh-HK)
4. 🇯🇵 日本語 (ja)
5. 🇰🇷 한국어 (ko)
6. 🇩🇪 Deutsch (de)
7. 🇪🇸 Español (es)
8. 🇫🇷 Français (fr-FR)
9. 🇵🇹 Português (pt)
10. 🇧🇷 Português (BR) (pt-BR)
11. 🇷🇺 Русский (ru)
12. 🇹🇷 Türkçe (tr)
13. 🇻🇳 Tiếng Việt (vi)
14. 🇮🇩 Bahasa Indonesia (id)
15. 🇺🇦 Українська (uk-UA)

---

## ✅ 最佳实践

1. **始终使用翻译key**：
   - ❌ `Text("Send")`
   - ✅ `Text(localization.t("send"))`

2. **为每个视图注入LocalizationManager**：
   ```swift
   @EnvironmentObject var localization: LocalizationManager
   ```

3. **翻译key命名规范**：
   - 使用下划线分隔：`transaction_sent`
   - 按功能分组：`settings_account`, `swap_from`
   - 保持简洁明确

4. **保持JSON文件同步**：
   - 所有15个locale文件必须有相同的key
   - 缺失的key会fallback到key本身

---

## 🚀 下一步行动

### 优先级1：核心功能页面
1. Dashboard/Assets (资产页面)
2. Send/Receive (发送/接收)
3. Swap (兑换)

### 优先级2：次要功能
4. NFT Gallery
5. Bridge
6. History

### 优先级3：其他页面
7. Token Approvals
8. Advanced Settings
9. About页面

---

## 🎓 示范代码参考

查看 `SettingsView.swift` 了解完整的本地化实现示例。

**关键要点**：
- ✅ 注入 `@EnvironmentObject var localization`
- ✅ 所有Text使用 `localization.t()`
- ✅ Section标题也使用翻译
- ✅ 语言切换后立即刷新
