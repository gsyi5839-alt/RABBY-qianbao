# iOS 系统开发 — 扩展钱包功能一比一迁移清单

> **审查基准**: 扩展钱包 v0.93.77 全部源码 (`src/ui/views/`, `src/ui/component/`, `src/background/service/`)
> **iOS 端现状（仓库内）**: 已存在原生 SwiftUI 钱包实现（`mobile/ios/RabbyMobile/`，约 72 个 Swift 文件），包含 Keyring/链/RPC/资产/交易/Swap/Bridge/NFT/DApp Browser/设置 等模块骨架；但仍有若干 P0 级别“派生/签名/WalletConnect/费率”等问题需修复后才能对齐扩展行为。
> **补充说明**: `apps/web/src/pages/LandingPage.tsx`、`apps/web/src/pages/MultiChainWalletPage.tsx` 为 Web 营销页，不代表 iOS 端能力。

---

## 0、仓库内 iOS 实现现状（以 `mobile/ios/` 为准）

### 0.1 已有目录
- iOS 入口：`mobile/ios/RabbyMobile/RabbyMobileApp.swift`
- 核心能力：`mobile/ios/RabbyMobile/Core/`
- UI：`mobile/ios/RabbyMobile/Views/`
- 工具：`mobile/ios/RabbyMobile/Utils/`

### 0.2 已实现（可复用，不需要从零）
- [x] 账户与密钥：`mobile/ios/RabbyMobile/Core/KeyringManager.swift` + `mobile/ios/RabbyMobile/Core/BIP39.swift`
- [x] 安全存储/解锁：`mobile/ios/RabbyMobile/Core/StorageManager.swift` + `mobile/ios/RabbyMobile/Core/BiometricAuthManager.swift` + `mobile/ios/RabbyMobile/Core/AutoLockManager.swift`
- [x] 链与 RPC：`mobile/ios/RabbyMobile/Core/NetworkManager.swift` + `mobile/ios/RabbyMobile/Core/CustomRPCManager.swift` + `mobile/ios/RabbyMobile/Core/SyncChainManager.swift`
- [x] 资产首页（含 Gas/链分布/曲线/代币/NFT/DeFi 仓位）：`mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 交易管理与历史：`mobile/ios/RabbyMobile/Core/TransactionManager.swift` + `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`
- [x] Swap/NFT/Bridge/DAppBrowser/Settings 页面骨架：`mobile/ios/RabbyMobile/Views/Swap/SwapView.swift` 等

### 0.3 P0 必须修复（影响“可用性/与扩展一致性/资产与签名正确性”）
- [ ] BIP44 子私钥派生算法不正确（当前用 XOR 占位）— `mobile/ios/RabbyMobile/Core/BIP44.swift`
- [ ] 交易签名 v 值未按 EIP-155 / typed-tx 规则处理（当前 27/28）— `mobile/ios/RabbyMobile/Utils/Secp256k1Helper.swift` + `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`
- [ ] EIP-712 TypedData 编码未实现（signTypedData 会报 notImplemented）— `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`
- [ ] WalletConnect v2 配对/连接未实现（pair/connect notImplemented）— `mobile/ios/RabbyMobile/Core/WalletConnectManager.swift`
- [ ] EIP-1559 fee 计算错误（baseFee 取值不对）— `mobile/ios/RabbyMobile/Core/TransactionManager.swift`
- [ ] DAppBrowser personal_sign / typedData 请求处理缺失 — `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`
- [ ] Keystore(JSON) 导入未实现 — `mobile/ios/RabbyMobile/Core/KeyringManager.swift`
- [ ] 相机扫码（WalletConnect URI/地址）未实现（UI 有入口但无 scanner）— `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`

### 0.4 资源/图标缺口（需要补齐的资产清单）
- [ ] i18n 翻译 JSON 未打包（I18nManager 从 bundle `locales/*.json` 读取，但目录缺失）— `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`
- [ ] 字体文件缺失（Info.plist 声明了 Lato/Roboto，但仓库未提供 ttf）— `mobile/ios/RabbyMobile/Info.plist`
- [ ] `Images.xcassets` 仅有 AppIcon，缺少品牌 Logo、Launch 视觉、业务图标（若不完全依赖 SF Symbols）— `mobile/ios/RabbyMobile/Images.xcassets`
- [ ] LaunchScreen 视觉（品牌 Logo/背景）— `mobile/ios/RabbyMobile/LaunchScreen.storyboard`
- [ ] 硬件钱包品牌图/引导图（Ledger/Trezor/OneKey/Keystone/ImKey 等）— 建议复用 `_raw/images/*` 并导入 `mobile/ios/RabbyMobile/Images.xcassets`
- [ ] 空状态插图（No data/No tx/No site 等）— 建议复用 `_raw/images/nodata-*.png`
- [ ] 链图标（ETH/BSC/Polygon/Arbitrum/Optimism/Base/...）— 可复用 `required-chain-icons/` 或 OpenAPI 的 `logo_url`
- [ ] Token 图标离线兜底（当前 `CryptoIconProvider` 使用线上 raw GitHub）— `mobile/ios/RabbyMobile/Utils/CryptoIconProvider.swift`
- [ ] iPad/Universal AppIcon slot（如需 iPad 支持）— `mobile/ios/RabbyMobile/Images.xcassets/AppIcon.appiconset/Contents.json`

#### 0.4.1 i18n locales（需要打包进 iOS bundle 的 JSON）

> iOS 当前读取路径：bundle `locales/<normalized>.json`（`zh-CN` → `zh_CN.json`），见 `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（I18nManager）。

- [ ] `mobile/ios/RabbyMobile/locales/en.json`
- [ ] `mobile/ios/RabbyMobile/locales/zh_CN.json`
- [ ] `mobile/ios/RabbyMobile/locales/zh_HK.json`
- [ ] `mobile/ios/RabbyMobile/locales/ja.json`
- [ ] `mobile/ios/RabbyMobile/locales/ko.json`
- [ ] `mobile/ios/RabbyMobile/locales/de.json`
- [ ] `mobile/ios/RabbyMobile/locales/es.json`
- [ ] `mobile/ios/RabbyMobile/locales/fr_FR.json`
- [ ] `mobile/ios/RabbyMobile/locales/pt_BR.json`
- [ ] `mobile/ios/RabbyMobile/locales/ru.json`
- [ ] `mobile/ios/RabbyMobile/locales/tr.json`
- [ ] `mobile/ios/RabbyMobile/locales/vi.json`
- [ ] `mobile/ios/RabbyMobile/locales/id.json`

建议来源与转换：
- 源文件：`_raw/locales/<locale>/messages.json`（Chrome extension 结构：`{ key: { message: string } }`）
- 目标格式：`{ "key": "message" }`（扁平 key-value）
- [ ] Xcode：确保 `locales/` 目录被加入 Build Phases → Copy Bundle Resources（并保持目录名为 `locales`）

#### 0.4.2 字体（如继续使用 Lato/Roboto）

> 当前 `Info.plist` 声明：`Lato-Bold.ttf`/`Lato-Regular.ttf`/`Roboto-*.ttf`，但仓库未提供 ttf（只有 `_raw/fonts/*.woff2`）。

- [ ] `mobile/ios/RabbyMobile/Resources/Fonts/Lato-Bold.ttf`
- [ ] `mobile/ios/RabbyMobile/Resources/Fonts/Lato-Regular.ttf`
- [ ] `mobile/ios/RabbyMobile/Resources/Fonts/Roboto-Bold.ttf`
- [ ] `mobile/ios/RabbyMobile/Resources/Fonts/Roboto-Medium.ttf`
- [ ] `mobile/ios/RabbyMobile/Resources/Fonts/Roboto-Regular.ttf`

（或）改用系统字体并移除 `UIAppFonts` 配置。
- [ ] Xcode：确保字体文件加入 Build Phases → Copy Bundle Resources，且文件名与 `Info.plist` 完全一致

#### 0.4.3 Images.xcassets（建议新增的图片/图标清单）

> 目标：补齐品牌/启动页/空状态/硬件钱包引导/链图标等；Token 图标建议“线上 + 缓存 + 少量离线兜底”，不要全量打包。

| 资产名（建议） | 用途 | 推荐来源（仓库已有） |
|---|---|---|
| Brand/RabbyLogo | App 品牌 Logo（深色） | `_raw/images/logo-rabby.svg`（建议转 PDF/单色 SVG） |
| Brand/RabbyLogoWhite | App 品牌 Logo（浅色） | `_raw/images/logo-white.svg` |
| Brand/RabbySiteLogo | 站点/营销 Logo（PNG 备选） | `_raw/images/rabby-site-logo.png` |
| Launch/LaunchLogo | 启动页 Logo | 复用 `Brand/RabbyLogo`（LaunchScreen.storyboard 可替换 label） |
| Onboarding/Welcome | 欢迎页插图 | `_raw/images/welcome-image.svg` |
| Onboarding/WelcomeStep1 | 新手引导图 1 | `_raw/images/welcome-step-1.png` |
| Onboarding/WelcomeStep2 | 新手引导图 2 | `_raw/images/welcome-step-2.png` |
| Empty/NoDataTx | 无交易空状态 | `_raw/images/nodata-tx.png` |
| Empty/NoDataSite | 无站点空状态 | `_raw/images/nodata-site.png` |
| Hardware/LedgerPlug | Ledger 连接引导图 | `_raw/images/ledger-plug.png` / `_raw/images/ledger-plug-1.png` |
| Hardware/LedgerBanner1 | Ledger banner | `_raw/images/ledger-banner-1.png` |
| Hardware/LedgerBanner2 | Ledger banner | `_raw/images/ledger-banner-2.png` |
| Hardware/TrezorPlug | Trezor 引导图 | `_raw/images/trezor-plug.png` |
| Hardware/OneKeyPlug | OneKey 引导图 | `_raw/images/onekey-plug.png` |
| Hardware/OneKeyBanner1 | OneKey banner | `_raw/images/onekey-banner-1.png` |
| Hardware/OneKeyBanner2 | OneKey banner | `_raw/images/onekey-banner-2.png` |
| Hardware/KeystonePlug | Keystone 引导图 | `_raw/images/keystone-plug.svg` / `_raw/images/keystone-plug-1.png` |
| Hardware/ImKeyPlug | ImKey 引导图 | `_raw/images/imkey-plug.svg` |
| Gnosis/LoadFailed | Gnosis 队列加载失败 | `_raw/images/gnosis-load-faild.png` |
| Masks/ImportMask | 导入遮罩/背景 | `_raw/images/import-mask.png` / `_raw/images/entry-import-mask.png` |
| Masks/WatchMask | Watch-only 遮罩/背景 | `_raw/images/watch-mask.png` |
| Masks/CreatePasswordMask | 创建密码遮罩/背景 | `_raw/images/create-password-mask.png` |

链图标（离线兜底，至少补齐主链）：
- [ ] `mobile/ios/RabbyMobile/Images.xcassets/Chains/`：建议先导入 `required-chain-icons/`（`arbitrum.png`、`optimism.png`、`base.png`、`bitcoin.png`、`tron.png`、`ton.png`、`okt.png`）
- [ ] 其余链：优先走 OpenAPI 的 `logo_url` + 缓存；离线时用通用占位图标

Token 图标（离线兜底）：
- [ ] 方案 A：仅内置少量 Top Token（ETH/USDT/USDC/DAI/WBTC…）+ 其余走线上缓存
- [ ] 方案 B：复用 `cryptocurrency-icons/`（体积大，不建议全量打包 App）

## 一、Dashboard 主页模块（扩展端拆解 16 项；iOS 对照逐条回填）

> iOS 列说明：✅=已有对应实现；⚠️=有骨架/部分实现/存在明显缺口；❌=未实现；N/A=扩展特有或 iOS 不适用（或被 iOS 原生能力替代）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 1.1 | Dashboard 主入口 | `src/ui/views/Dashboard/index.tsx` | 整合所有子模块的主页 | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（Assets 即主页） |
| 1.2 | DashboardHeader 头部 | `Dashboard/components/DashboardHeader/` | 当前账户名、地址、复制、切换账户、QR码、全屏 | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` + `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift` |
| 1.3 | BalanceView 余额展示 | `Dashboard/components/BalanceView/` | 总资产余额 + 链列表 + 资产曲线图(CurveView) | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` + `mobile/ios/RabbyMobile/Views/Assets/BalanceCurveView.swift` + `mobile/ios/RabbyMobile/Views/Assets/ChainBalanceView.swift` |
| 1.4 | DashboardPanel 功能面板 | `Dashboard/components/DashboardPanel/` | 可拖拽排序的功能入口网格(Send/Receive/Swap/Bridge/NFT/Perps/Approvals/Gas等) | ⚠️ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（快捷按钮，非可拖拽网格） |
| 1.5 | GasPriceBar Gas价格栏 | `Dashboard/components/GasPriceBar/` | 实时显示当前链 Gas 价格 | ✅ `mobile/ios/RabbyMobile/Views/Assets/GasPriceBarView.swift` |
| 1.6 | CurrentConnection 当前连接 | `Dashboard/components/CurrentConnection/` | 当前 Dapp 连接状态 | ⚠️ `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`（`DAppPermissionManager` 有数据结构但未贯通 UI） |
| 1.7 | PendingTxs 待处理交易 | `Dashboard/components/PendingTxs.tsx` | 待处理交易数量提示 | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（toolbar badge） |
| 1.8 | PendingApproval 待审批 | `Dashboard/components/PendingApproval.tsx` | 待审批请求弹窗 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 pending 队列） |
| 1.9 | Queue 队列 | `Dashboard/components/Queue.tsx` | Gnosis 交易队列提示 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/GnosisQueueView.swift`（未集成到主页） |
| 1.10 | TokenDetailPopup 代币详情 | `Dashboard/components/TokenDetailPopup/` | 代币详情弹窗(价格、历史、屏蔽/自定义按钮、诈骗提示) | ✅ `mobile/ios/RabbyMobile/Views/Assets/TokenDetailView.swift`（Sheet/页面式） |
| 1.11 | NFT 弹窗 | `Dashboard/components/NFT/` | NFT头像/预览弹窗 | ✅ `mobile/ios/RabbyMobile/Views/Assets/NFTDetailView.swift` |
| 1.12 | Security 安全状态 | `Dashboard/components/Security/` | 安全状态提示 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（交易内安全检查；无 Dashboard 独立卡片） |
| 1.13 | Settings 设置面板 | `Dashboard/components/Settings/` | 完整的设置抽屉(详见第十章) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（独立 Tab/页面） |
| 1.14 | RecentConnections 最近连接 | `Dashboard/components/RecentConnections/` | 最近连接的 Dapp 列表 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（展示依赖 `DAppPermissionManager`，目前未写入连接数据） |
| 1.15 | Contacts 联系人 | `Dashboard/components/Contacts/` | 联系人管理弹窗 | ⚠️ `mobile/ios/RabbyMobile/Core/ContactBookManager.swift` + `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（SelectToAddress） |
| 1.16 | RabbyPointsPopup 积分弹窗 | `Dashboard/components/RabbyPointsPopup/` | Rabby 积分弹窗入口 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（RabbyPointsView，非 popup） |

---

## 二、发送/接收功能（扩展端拆解 12 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 2.1 | SendToken 主页 | `src/ui/views/SendToken/index.tsx` | 发送代币主页面 | ✅ `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift` |
| 2.2 | 链选择器(发送) | `SendToken/components/ChainSelectorInSend.tsx` | 发送时选择链 | ⚠️ `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`（依赖 `selectedChain`；页面内无链选择器） |
| 2.3 | MaxButton | `SendToken/components/MaxButton.tsx` | 最大金额按钮 | ✅ `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift` |
| 2.4 | SwitchReserveGas | `SendToken/components/SwitchReserveGas.tsx` | 保留 Gas 开关 | ❌ |
| 2.5 | PreExecTransactionExplain | `SendToken/components/PreExecTransactionExplain.tsx` | 预执行交易解释 | ❌ |
| 2.6 | ConfirmAddToContacts | `SendToken/components/ModalConfirmAddToContacts.tsx` | 添加到联系人确认 | ❌（iOS 暂无“发送后加联系人”确认流程） |
| 2.7 | ConfirmAllowTransfer | `SendToken/components/ModalConfirmAllowTransfer.tsx` | 允许转账确认(白名单检查) | ⚠️ `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`（Whitelist Warning 简化版） |
| 2.8 | SendNFT 发送NFT | `src/ui/views/SendNFT/index.tsx` | 发送 NFT 页面 | ⚠️ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift` + `mobile/ios/RabbyMobile/Core/NFTManager.swift`（chainId/1155 calldata 需修） |
| 2.9 | Receive 接收 | `src/ui/views/Receive/index.tsx` | 接收页面(二维码+地址) | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（ReceiveView） |
| 2.10 | SelectToAddress | `src/ui/views/SelectToAddress/` | 选择收款地址(导入地址/白名单/手动输入) | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（SelectToAddressView） |
| 2.11 | WhitelistInput | `src/ui/views/WhitelistInput/` | 白名单地址输入 | ✅ `mobile/ios/RabbyMobile/Views/Settings/WhitelistInputView.swift` |
| 2.12 | GasAccount | `src/ui/views/GasAccount/` | Gas代付(登录/充值/提现/历史/切换地址) | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift` + `mobile/ios/RabbyMobile/Core/GasAccountManager.swift`（UI/接口不完整） |

---

## 三、DEX Swap 兑换模块（扩展端拆解 14 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 3.1 | Swap 主页 | `src/ui/views/Swap/index.tsx` | Swap 主入口 | ⚠️ `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift`（未完成 token 选择/执行闭环） |
| 3.2 | Swap Main | `Swap/Component/Main.tsx` | 核心交换表单(代币选择、金额输入) | ⚠️ `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift` |
| 3.3 | Swap Header | `Swap/Component/Header.tsx` | Swap 头部(设置入口) | ❌（iOS 暂无设置入口/聚合器选择等） |
| 3.4 | Token 选择 | `Swap/Component/Token.tsx` | 代币选择渲染 | ❌（`SwapView` 中 `showTokenSelector` 未接入 Sheet） |
| 3.5 | Quotes 报价列表 | `Swap/Component/Quotes.tsx` | 多DEX报价展示 | ⚠️ `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift` + `mobile/ios/RabbyMobile/Core/SwapManager.swift` |
| 3.6 | QuoteItem 报价项 | `Swap/Component/QuoteItem.tsx` | 单个报价详情(价格/Gas/路由) | ⚠️ `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift` |
| 3.7 | History 交换历史 | `Swap/Component/History.tsx` | Swap 历史记录 | ⚠️ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`（Swap filter）+ `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift`（未完全写入） |
| 3.8 | PendingTx 待处理 | `Swap/Component/PendingTxItem.tsx` | 待处理的Swap交易 | ⚠️ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`（仅通用 pending） |
| 3.9 | Slippage 滑点 | `Swap/hooks/slippage.tsx` | 滑点设置逻辑 | ⚠️ `mobile/ios/RabbyMobile/Core/SwapManager.swift`（有字段；UI 未完成） |
| 3.10 | AutoSlippage | `Swap/hooks/autoSlippageEffect.tsx` | 自动滑点调整 | ❌ |
| 3.11 | Quote 报价逻辑 | `Swap/hooks/quote.tsx` | 获取报价核心逻辑 | ⚠️ `mobile/ios/RabbyMobile/Core/SwapManager.swift`（`user_address` 为空/amount&value 处理不一致需修） |
| 3.12 | TwoStepSwap | `Swap/hooks/twoStepSwap.tsx` | 两步交换(Approve+Swap) | ❌ |
| 3.13 | RabbyFeePopup | `Swap/Component/RabbyFeePopup.tsx` | Rabby 费用说明弹窗 | ❌ |
| 3.14 | ReserveGasPopup | `Swap/Component/ReserveGasPopup.tsx` | 保留Gas费弹窗 | ❌ |

---

## 四、Bridge 跨链桥模块（扩展端拆解 12 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 4.1 | Bridge 主页 | `src/ui/views/Bridge/index.tsx` | 跨链桥主入口 | ⚠️ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift`（执行/amount 处理需修） |
| 4.2 | BridgeContent | `Bridge/Component/BridgeContent.tsx` | 跨链桥核心表单 | ⚠️ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift` |
| 4.3 | BridgeHeader | `Bridge/Component/BridgeHeader.tsx` | 跨链桥头部 | ❌（iOS 暂无聚合器/设置等 header 区域） |
| 4.4 | BridgeToken 代币选择 | `Bridge/Component/BridgeToken.tsx` | 跨链代币选择 | ⚠️ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift`（当前仅 native token） |
| 4.5 | BridgeToTokenSelect | `Bridge/Component/BridgeToTokenSelect.tsx` | 目标链代币选择 | ❌ |
| 4.6 | BridgeQuotes 报价列表 | `Bridge/Component/BridgeQuotes.tsx` | 多桥报价展示 | ⚠️ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift` + `mobile/ios/RabbyMobile/Core/BridgeManager.swift` |
| 4.7 | BridgeQuoteItem | `Bridge/Component/BridgeQuoteItem.tsx` | 单个桥报价详情 | ⚠️ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift` |
| 4.8 | BridgeSlippage | `Bridge/Component/BridgeSlippage.tsx` | 跨链桥滑点设置 | ❌ |
| 4.9 | BridgeSwitchButton | `Bridge/Component/BridgeSwitchButton.tsx` | 链方向切换按钮 | ✅ `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift`（swapChains） |
| 4.10 | BridgeHistory | `Bridge/Component/BridgeHistory.tsx` | 跨链历史记录 | ⚠️ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`（Bridge filter）+ `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift` |
| 4.11 | PendingTx 待处理 | `Bridge/Component/PendingTx.tsx` | 待处理跨链交易 | ⚠️ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`（仅通用 pending） |
| 4.12 | ShowMoreGasModal | `Bridge/Component/ShowMoreGasModal.tsx` | Gas费用详情弹窗 | ❌ |

---

## 五、Perps 合约交易模块（扩展端拆解 19 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 5.1 | Perps 首页 | `src/ui/views/Perps/screen/home.tsx` | 合约交易首页 | ⚠️ `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（PerpsView 骨架） |
| 5.2 | SingleCoin 单币页 | `Perps/screen/SingleCoin.tsx` | 单币合约交易页 | ⚠️ `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（coin selector） |
| 5.3 | ExploreMore 探索更多 | `Perps/screen/ExploreMore.tsx` | 探索更多合约 | ❌ |
| 5.4 | HistoryPage 历史 | `Perps/screen/HistoryPage.tsx` | 合约交易历史 | ❌ |
| 5.5 | Chart K线图 | `Perps/components/Chart.tsx` | K线图/价格图表 | ❌ |
| 5.6 | PositionItem 持仓 | `Perps/components/PositionItem.tsx` | 持仓详情项 | ⚠️ `mobile/ios/RabbyMobile/Core/PerpsManager.swift`（positions/orders 未对接后端） |
| 5.7 | LeverageInput 杠杆 | `Perps/components/LeverageInput.tsx` | 杠杆倍数输入 | ⚠️ `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift` |
| 5.8 | MarginInput 保证金 | `Perps/components/MarginInput.tsx` | 保证金输入 | ⚠️ `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（size 输入） |
| 5.9 | OpenPositionPopup | `Perps/popup/OpenPositionPopup.tsx` | 开仓弹窗 | ❌ |
| 5.10 | ClosePositionPopup | `Perps/popup/ClosePositionPopup.tsx` | 平仓弹窗 | ❌ |
| 5.11 | AddPositionPopup | `Perps/popup/AddPositionPopup.tsx` | 加仓弹窗 | ❌ |
| 5.12 | EditMarginPopup | `Perps/popup/EditMarginPopup.tsx` | 编辑保证金弹窗 | ❌ |
| 5.13 | DepositAmountPopup | `Perps/popup/DepositAmountPopup.tsx` | 充值金额弹窗 | ❌ |
| 5.14 | LoginPopup | `Perps/popup/LoginPopup.tsx` | Perps 登录弹窗 | ❌ |
| 5.15 | SearchPerpsPopup | `Perps/popup/SearchPerpsPopup.tsx` | 搜索合约弹窗 | ❌ |
| 5.16 | TokenSelectPopup | `Perps/popup/TokenSelectPopup.tsx` | 代币选择弹窗 | ❌ |
| 5.17 | RiskLevelPopup | `Perps/popup/RiskLevelPopup.tsx` | 风险等级弹窗 | ❌ |
| 5.18 | HistoryDetailPopup | `Perps/popup/HistoryDetailPopup.tsx` | 历史详情弹窗 | ❌ |
| 5.19 | PerpsInvitePopup | `Perps/popup/PerpsInvitePopup.tsx` | 邀请弹窗 | ❌ |

---

## 六、GasAccount Gas代付模块（扩展端拆解 10 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 6.1 | GasAccount 主页 | `src/ui/views/GasAccount/index.tsx` | Gas代付主页 | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift` |
| 6.2 | GasAccountCard | `GasAccount/components/GasAccountCard.tsx` | Gas账户卡片 | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（简化卡片） |
| 6.3 | GasAccountLoginCard | `GasAccount/components/GasAccountLoginCard.tsx` | 登录卡片 | ❌（iOS 暂无签名登录流程 UI） |
| 6.4 | LoginPopup | `GasAccount/components/LoginPopup.tsx` | Gas登录弹窗 | ❌ |
| 6.5 | DepositPopup | `GasAccount/components/DepositPopup.tsx` | 充值弹窗 | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（deposit 为占位） |
| 6.6 | WithdrawPopup | `GasAccount/components/WithdrawPopup.tsx` | 提现弹窗 | ❌ |
| 6.7 | History | `GasAccount/components/History.tsx` | Gas使用历史 | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（本地占位） |
| 6.8 | LogoutPopup | `GasAccount/components/LogoutPopop.tsx` | 退出登录弹窗 | ❌ |
| 6.9 | SwitchLoginAddrModal | `GasAccount/components/SwitchLoginAddrModal.tsx` | 切换登录地址 | ❌ |
| 6.10 | GasAccountTxPopups | `GasAccount/components/GasAccountTxPopups.tsx` | Gas交易弹窗 | ❌ |

---

## 七、交易历史模块（扩展端拆解 8 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 7.1 | History 主页 | `src/ui/views/History/index.tsx` | 交易历史主页 | ✅ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift` |
| 7.2 | History 过滤诈骗 | `History` (isFitlerScam=true) | 过滤诈骗交易视图 | ❌（iOS 暂无 is_scam 过滤开关） |
| 7.3 | HistoryItem | `History/components/HistoryItem.tsx` | 单条历史记录 | ✅ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`（行渲染） |
| 7.4 | HistoryList | `History/components/HistoryList.tsx` | 历史列表 | ✅ `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift` |
| 7.5 | TransactionHistory | `src/ui/views/TransactionHistory/` | 详细交易历史(内存池/取消/加速) | ⚠️ `mobile/ios/RabbyMobile/Core/TransactionManager.swift`（cancel/speedUp 有方法；缺少详情页 UI） |
| 7.6 | CancelTxPopup | `TransactionHistory/components/CancelTxPopup.tsx` | 取消交易弹窗 | ❌ |
| 7.7 | SignedTextHistory | `src/ui/views/SignedTextHistory/` | 签名文本历史记录 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（SignedTextHistoryView）+ `mobile/ios/RabbyMobile/Core/SignHistoryManager.swift` |
| 7.8 | Activities | `src/ui/views/Activities/` | 活动/签名记录页 | ✅ `mobile/ios/RabbyMobile/Views/Activities/ActivitiesView.swift` |

---

## 八、NFT 模块（扩展端拆解 6 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 8.1 | NFTView 主页 | `src/ui/views/NFTView/index.tsx` | NFT 浏览主页 | ✅ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift`（另有 `NFTGalleryView` 嵌入资产页） |
| 8.2 | CollectionCard | `NFTView/CollectionCard.tsx` | NFT合集卡片 | ✅ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift` |
| 8.3 | useCollection | `NFTView/useCollection.tsx` | NFT合集数据Hook | ✅ `mobile/ios/RabbyMobile/Core/NFTManager.swift` |
| 8.4 | NFTEmpty | `NFTView/NFTEmpty.tsx` | 空状态展示 | ✅ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift` |
| 8.5 | ModalPreviewNFTItem | `src/ui/component/ModalPreviewNFTItem/` | NFT预览弹窗 | ✅ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift`（Sheet: NFTDetailView） |
| 8.6 | NFTNumberInput | `src/ui/component/NFTNumberInput/` | NFT数量输入 | ⚠️ `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift`（SendNFTView 有数量输入；ERC1155 calldata 未完成） |

---

## 九、授权管理模块（扩展端拆解 7 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 9.1 | TokenApproval 主页 | `src/ui/views/TokenApproval/index.tsx` | Token授权管理主页 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（TokenApprovalView：未接 OpenAPI） |
| 9.2 | ApprovalCard | `TokenApproval/components/ApprovalCard.tsx` | 授权卡片 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（列表行） |
| 9.3 | PopupApprovalCard | `TokenApproval/components/PopupApprovalCard.tsx` | 授权详情弹窗 | ❌ |
| 9.4 | PopupSearch 搜索 | `TokenApproval/components/PopupSearch.tsx` | 搜索授权 | ❌ |
| 9.5 | NFTApproval 主页 | `src/ui/views/NFTApproval/index.tsx` | NFT授权管理主页 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（NFTApprovalView，读 OpenAPI） |
| 9.6 | NFTContractList | `NFTApproval/components/NFTContractList.tsx` | NFT合约列表 | ⚠️ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（未按合约分组） |
| 9.7 | NFTList | `NFTApproval/components/NFTList.tsx` | NFT列表 | ⚠️ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift` |

---

## 十、交易审批/签名引擎（扩展端拆解 30 组；iOS 对照逐条回填） — 最复杂模块

### 10.1 交易类型 Actions（扩展端拆解 20 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.1.1 | Send 发送 | `Approval/components/Actions/Send.tsx` | 发送交易解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.2 | Swap 兑换 | `Approval/components/Actions/Swap.tsx` | Swap交易解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.3 | CrossSwapToken | `Approval/components/Actions/CrossSwapToken.tsx` | 跨链Swap解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.4 | CrossToken | `Approval/components/Actions/CrossToken.tsx` | 跨链转账解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.5 | TokenApprove | `Approval/components/Actions/TokenApprove.tsx` | Token授权解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.6 | RevokeTokenApprove | `Approval/components/Actions/RevokeTokenApprove.tsx` | 撤销授权 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.7 | ApproveNFT | `Approval/components/Actions/ApproveNFT.tsx` | NFT授权 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.8 | ApproveNFTCollection | `Approval/components/Actions/ApproveNFTCollection.tsx` | NFT合集授权 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.9 | RevokeNFT | `Approval/components/Actions/RevokeNFT.tsx` | 撤销NFT授权 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.10 | SendNFT | `Approval/components/Actions/SendNFT.tsx` | 发送NFT解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.11 | ContractCall | `Approval/components/Actions/ContractCall.tsx` | 合约调用解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.12 | DeployContract | `Approval/components/Actions/DeployContract.tsx` | 部署合约解析 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.13 | CancelTx | `Approval/components/Actions/CancelTx.tsx` | 取消交易 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.14 | WrapToken | `Approval/components/Actions/WrapToken.tsx` | Wrap代币 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.15 | UnWrapToken | `Approval/components/Actions/UnWrapToken.tsx` | UnWrap代币 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.16 | AddLiquidity | `Approval/components/Actions/AddLiquidity.tsx` | 添加流动性 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.17 | MultiSwap | `Approval/components/Actions/MultiSwap.tsx` | 多路径Swap | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.18 | PushMultiSig | `Approval/components/Actions/PushMultiSig.tsx` | 推送多签 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.19 | AssetOrder | `Approval/components/Actions/AssetOrder.tsx` | 资产订单 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |
| 10.1.20 | TransferOwner | `Approval/components/Actions/TransferOwner.tsx` | 转移所有权 | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（无 action parser，仅 method decode） |

### 10.2 TypedData Actions（扩展端拆解 11 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.2.1 | Permit | `Approval/components/TypedDataActions/Permit.tsx` | Permit签名 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.2 | Permit2 | `Approval/components/TypedDataActions/Permit2.tsx` | Permit2签名 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.3 | BatchPermit2 | `Approval/components/TypedDataActions/BatchPermit2.tsx` | 批量Permit2 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.4 | SwapTokenOrder | `Approval/components/TypedDataActions/SwapTokenOrder.tsx` | Swap订单签名 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.5 | BuyNFT | `Approval/components/TypedDataActions/BuyNFT.tsx` | 购买NFT | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.6 | SellNFT | `Approval/components/TypedDataActions/SellNFT.tsx` | 出售NFT | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.7 | BatchSellNFT | `Approval/components/TypedDataActions/BatchSellNFT.tsx` | 批量出售NFT | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.8 | SignMultisig | `Approval/components/TypedDataActions/SignMultisig.tsx` | 多签签名 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |
| 10.2.9 | CoboSafeCreate | `Approval/components/TypedDataActions/CoboSafeCreate.tsx` | Cobo Safe创建 | ❌ |
| 10.2.10 | CoboSafe修改委托 | `Approval/components/TypedDataActions/CoboSafeModification*.tsx` | Cobo Safe修改(3个) | ❌ |
| 10.2.11 | ContractCall(Typed) | `Approval/components/TypedDataActions/ContractCall.tsx` | TypedData合约调用 | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（EIP-712 notImplemented） |

### 10.3 签名/等待流程（扩展端拆解 10 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.3.1 | SignTx 签名交易 | `Approval/components/SignTx.tsx` | 交易签名主页 | ✅ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift` |
| 10.3.2 | SignText 签名文本 | `Approval/components/SignText.tsx` | 文本签名(personal_sign) | ⚠️ `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`（SignTextApprovalView 存在，但 DAppBrowser 未接入） |
| 10.3.3 | SignTypedData | `Approval/components/SignTypedData.tsx` | TypedData签名(EIP-712) | ❌ `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（TypedData notImplemented） |
| 10.3.4 | ETHSign | `Approval/components/ETHSign.tsx` | eth_sign(危险签名) | ❌ |
| 10.3.5 | Decrypt | `Approval/components/Decrypt.tsx` | 解密请求 | ❌ |
| 10.3.6 | GetPublicKey | `Approval/components/GetPublicKey.tsx` | 获取公钥 | ❌ |
| 10.3.7 | LedgerHardwareWaiting | `Approval/components/LedgerHardwareWaiting.tsx` | Ledger等待签名 | ❌（Ledger 连接页存在，但未接入 Approval 等待态） |
| 10.3.8 | ImKeyHardwareWaiting | `Approval/components/ImKeyHardwareWaiting.tsx` | imKey等待签名 | ❌ |
| 10.3.9 | QRHardWareWaiting | `Approval/components/QRHardWareWaiting/` | QR码硬件等待(Keystone) | ❌ |
| 10.3.10 | WatchAddressWaiting | `Approval/components/WatchAddressWaiting/` | 观察地址等待签名 | ❌ |

### 10.4 迷你签名（扩展端拆解 3 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.4.1 | MiniSignTx | `Approval/components/MiniSignTx/` | 迷你签名交易(批量) | ❌ |
| 10.4.2 | MiniPersonalMessage | `Approval/components/MiniPersonalMessgae/` | 迷你个人签名 | ❌ |
| 10.4.3 | MiniSignTypedData | `Approval/components/MiniSignTypedData/` | 迷你TypedData签名 | ❌ |

### 10.5 安全引擎（扩展端拆解 3 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.5.1 | SecurityEngine | `Approval/components/SecurityEngine/` | 安全规则检查UI | ⚠️ `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift` + `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift` + `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift` |
| 10.5.2 | RuleDrawer | `Approval/components/SecurityEngine/RuleDrawer.tsx` | 安全规则详情 | ❌ |
| 10.5.3 | BalanceChange | `Approval/components/TxComponents/BalanceChange.tsx` | 余额变化预览 | ❌ |

### 10.6 其他审批组件（扩展端拆解 7 项）
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 10.6.1 | Connect 连接请求 | `Approval/components/Connect/` | Dapp连接请求(选择钱包/权限) | ❌（仅有 `DAppPermissionManager` 数据结构） |
| 10.6.2 | AddChain 添加链 | `Approval/components/AddChain/` | 添加新链请求 | ❌ |
| 10.6.3 | SwitchChain 切换链 | `Approval/components/SwitchChain/` | 切换链请求 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（wallet_switchEthereumChain 直切，无审批 UI） |
| 10.6.4 | AddAsset 添加资产 | `Approval/components/AddAsset.tsx` | 添加代币请求 | ❌ |
| 10.6.5 | ImportAddress 导入地址 | `Approval/components/ImportAddress.tsx` | 导入地址请求 | ❌ |
| 10.6.6 | FooterBar | `Approval/components/FooterBar/` | 签名底部栏(16个组件:各钱包签名按钮) | ❌ |
| 10.6.7 | BroadcastMode | `Approval/components/BroadcastMode/` | 广播模式选择 | ❌ |

---

## 十一、账户创建/导入流程（扩展端拆解 16 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 11.1 | Welcome 欢迎页 | `src/ui/views/Welcome.tsx` | 首次打开欢迎页 | ✅ `mobile/ios/RabbyMobile/Views/RootView.swift`（OnboardingView） |
| 11.2 | CreatePassword | `src/ui/views/CreatePassword.tsx` | 创建密码 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift` |
| 11.3 | Unlock 解锁 | `src/ui/views/Unlock/` | 解锁页面 | ✅ `mobile/ios/RabbyMobile/Views/RootView.swift`（UnlockView） |
| 11.4 | ForgotPassword | `src/ui/views/ForgotPassword/` | 忘记密码 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（ForgotPasswordView） |
| 11.5 | NoAddress | `src/ui/views/NoAddress/` | 无地址时引导 | ⚠️（iOS 暂无独立 NoAddress 页面；需梳理“已初始化但无可用地址”分支） |
| 11.6 | ImportMode | `src/ui/views/ImportMode.tsx` | 导入模式选择 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift` |
| 11.7 | ImportPrivateKey | `src/ui/views/ImportPrivateKey.tsx` | 导入私钥 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（ImportPrivateKeyView） |
| 11.8 | ImportMnemonics | `src/ui/views/ImportMnemonics/InputMnemonics.tsx` | 导入助记词 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/ImportWalletView.swift` |
| 11.9 | CreateMnemonics | `src/ui/views/CreateMnemonics/` | 创建助记词(显示+风险确认) | ✅ `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift` |
| 11.10 | ImportJson | `src/ui/views/ImportJson.tsx` | 导入JSON钱包文件 | ⚠️ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（JsonKeystoreImportView：Core 未实现解密） |
| 11.11 | ImportWatchAddress | `src/ui/views/ImportWatchAddress.tsx` | 导入观察地址 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（WatchAddressImportView） |
| 11.12 | AddFromCurrentSeedPhrase | `src/ui/views/AddFromCurrentSeedPhrase/` | 从已有种子派生新地址 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportSuccessAddFromSeedView.swift`（AddFromSeedPhraseView） |
| 11.13 | ImportMetaMask | `src/ui/views/ImportMyMetaMaskAccount/` | 导入MetaMask账户 | ❌ |
| 11.14 | SelectAddress | `src/ui/views/SelectAddress/` | 导入后选择地址(分页) | ✅ `mobile/ios/RabbyMobile/Views/Import/SelectAddressView.swift` + `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`（HDManagerView） |
| 11.15 | ImportSuccess | `src/ui/views/ImportSuccess/` | 导入成功页 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportSuccessAddFromSeedView.swift` |
| 11.16 | AddAddress | `src/ui/views/AddAddress/` | 添加地址入口页 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（Import hub） |

---

## 十二、新用户引导流程（扩展端拆解 14 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 12.1 | Guide 引导 | `NewUserImport/Guide.tsx` | 新用户引导首页 | ✅ `mobile/ios/RabbyMobile/Views/RootView.swift`（Onboarding pages） |
| 12.2 | ImportList 列表 | `NewUserImport/ImportList.tsx` | 导入方式列表 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift` |
| 12.3 | ImportPrivateKey | `NewUserImport/ImportPrivateKey.tsx` | 新用户导入私钥 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（ImportPrivateKeyView） |
| 12.4 | ImportSeedPhrase | `NewUserImport/ImportSeedPhrase.tsx` | 新用户导入助记词 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/ImportWalletView.swift` |
| 12.5 | CreateSeedPhrase | `NewUserImport/CreateSeedPhrase.tsx` | 新用户创建助记词 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift` |
| 12.6 | BackupSeedPhrase | `NewUserImport/BackupSeedPhrase.tsx` | 备份助记词 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift` |
| 12.7 | SetPassword | `NewUserImport/SetPassword.tsx` | 设置密码 | ✅ `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift` |
| 12.8 | ImportGnosis | `NewUserImport/ImportGnosisAddress.tsx` | 新用户导入Gnosis | ⚠️ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（GnosisSafeImportView 骨架） |
| 12.9 | ImportLedger | `NewUserImport/ImportLedger.tsx` | 新用户连接Ledger | ⚠️ `mobile/ios/RabbyMobile/Views/HardwareWallet/LedgerConnectView.swift` |
| 12.10 | ImportImKey | `NewUserImport/ImportImKey.tsx` | 新用户连接imKey | ❌ |
| 12.11 | ImportKeystone | `NewUserImport/ImportKeystone.tsx` | 新用户连接Keystone | ❌ |
| 12.12 | ImportOneKey | `NewUserImport/ImportOnekey.tsx` | 新用户连接OneKey | ❌ |
| 12.13 | SelectAddress | `NewUserImport/SelectAddress.tsx` | 新用户选择地址 | ✅ `mobile/ios/RabbyMobile/Views/Import/SelectAddressView.swift` |
| 12.14 | Success/ReadyToUse | `NewUserImport/Success.tsx` + `ReadyToUse.tsx` | 成功+准备使用 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportSuccessAddFromSeedView.swift` |

---

## 十三、硬件钱包连接（扩展端拆解 8 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 13.1 | ImportHardware 入口 | `src/ui/views/ImportHardware/index.tsx` | 硬件钱包选择入口 | ✅ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（Hardware Wallets 区域） |
| 13.2 | LedgerConnect | `ImportHardware/LedgerConnect/` | Ledger连接(含Banner) | ⚠️ `mobile/ios/RabbyMobile/Views/HardwareWallet/LedgerConnectView.swift` + `mobile/ios/RabbyMobile/Core/HardwareWallet/BluetoothManager.swift` |
| 13.3 | TrezorConnect | `ImportHardware/TrezorConnect/` | Trezor连接 | ❌ |
| 13.4 | OneKeyConnect | `ImportHardware/OneKeyConnect/` | OneKey连接(含图片轮播) | ❌ |
| 13.5 | KeystoneConnect | `ImportHardware/KeystoneConnect/` | Keystone连接 | ❌ |
| 13.6 | ImKeyConnect | `ImportHardware/ImKeyConnect/` | imKey连接 | ❌ |
| 13.7 | QRCodeConnect | `ImportHardware/QRCodeConnect/` | QR扫码连接 | ❌（iOS 相机扫码未实现） |
| 13.8 | HDManager | `src/ui/views/HDManager/` | HD地址管理(Ledger/Trezor/OneKey/GridPlus/BitBox02/imKey/Keystone/QRCode/Mnemonic) | ⚠️ `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`（HDManagerView；BIP44 correctness 见 0.3） |

---

## 十四、多签/协议钱包（扩展端拆解 5 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 14.1 | ImportGnosisAddress | `src/ui/views/ImportGnosisAddress/` | 导入Gnosis Safe地址 | ⚠️ `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`（GnosisSafeImportView）+ `mobile/ios/RabbyMobile/Core/WatchGnosisSessionKeyrings.swift` |
| 14.2 | GnosisQueue 队列 | `src/ui/views/GnosisQueue/` | Gnosis交易队列+消息队列 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/GnosisQueueView.swift` |
| 14.3 | ImportCoboArgus | `src/ui/views/ImportCoboArgus/` | 导入Cobo Argus | ❌ |
| 14.4 | ImportCoinbase | `src/ui/views/ImportCoinbase/` | 导入Coinbase | ❌ |
| 14.5 | WalletConnect | `src/ui/views/WalletConnect/` | WalletConnect 连接 | ⚠️ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（WalletConnectView）+ `mobile/ios/RabbyMobile/Core/WalletConnectManager.swift`（notImplemented） |

---

## 十五、设置/管理功能（扩展端拆解 20 项；iOS 对照逐条回填）

### 15.1 设置面板内功能 (Dashboard Settings)
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 15.1.1 | LockWallet 锁定钱包 | Settings (快捷键 Cmd+L) | 锁定钱包 | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（Lock Wallet） |
| 15.1.2 | SignatureRecord 签名记录 | → `/activities` | 签名记录入口 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（SignedTextHistoryView）+ `mobile/ios/RabbyMobile/Views/Activities/ActivitiesView.swift` |
| 15.1.3 | ManageAddress 地址管理 | → `/settings/address` | 地址管理入口 | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（AddressManagementView） |
| 15.1.4 | Ecosystem 生态 | EcosystemBanner | 生态入口(DBK Chain/Sonic) | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（仅通用 DApp Browser） |
| 15.1.5 | SyncToMobile | → `/sync` | 同步到手机 | ❌ |
| 15.1.6 | SearchDapps 搜索Dapp | → `/dapp-search` | Dapp搜索入口 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（URL 输入/Popular 列表，非搜索页 1:1） |
| 15.1.7 | ConnectedDapps | RecentConnections | 已连接Dapp列表 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（ConnectedSitesView） |
| 15.1.8 | PwdForNonWhitelisted | Switch开关 | 非白名单转账密码验证 | ❌（iOS 仅提示警告，不做密码二次确认） |
| 15.1.9 | DappAccount | Switch开关 + 介绍弹窗 | Dapp账户模式 | ❌ |
| 15.1.10 | CustomTestnet | → `/custom-testnet` | 自定义测试网 | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（CustomTestnetView）+ `mobile/ios/RabbyMobile/Core/CustomTestnetManager.swift` |
| 15.1.11 | CustomRPC | → `/custom-rpc` | 自定义RPC | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（CustomRPCView）+ `mobile/ios/RabbyMobile/Core/CustomRPCManager.swift` |
| 15.1.12 | SwitchLang 语言 | SwitchLangModal | 语言切换 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（Picker 已有；i18n 资源缺失见 0.4） |
| 15.1.13 | ThemeMode 主题 | SwitchThemeModal | 主题切换(亮/暗/跟随系统) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift` + `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` |
| 15.1.14 | MetaMaskMode | → `/metamask-mode-dapps` | MetaMask模式Dapp管理 | ❌ |
| 15.1.15 | AutoLock 自动锁定 | AutoLockModal | 自动锁定时间设置(永不/10min/1h/4h/1d/7d) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift` + `mobile/ios/RabbyMobile/Core/AutoLockManager.swift` |
| 15.1.16 | ClearPending 清除待处理 | ResetAccountModal | 清除待处理交易+Nonce | ❌ |

### 15.2 独立设置页面
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 15.2.1 | ManageAddress | `src/ui/views/ManageAddress/` | 地址分组管理(删除/排序) | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（AddressManagementView：hide/unhide，未做分组/排序） |
| 15.2.2 | AddressDetail | `src/ui/views/AddressDetail/` | 地址详情(备份/Gnosis信息/CoboArgus/硬件状态) | ⚠️ `mobile/ios/RabbyMobile/Views/AddressDetail/AddressDetailView.swift` |
| 15.2.3 | AddressBackup 私钥 | `src/ui/views/AddressBackup/PrivateKey.tsx` | 备份私钥 | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（AddressBackupView） |
| 15.2.4 | AddressBackup 助记词 | `src/ui/views/AddressBackup/Mnemonics.tsx` | 备份助记词(含Slip39) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（AddressBackupView） |

---

## 十六、Ecology 链上生态（扩展端拆解 7 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 16.1 | Ecology 入口 | `src/ui/views/Ecology/index.tsx` | 生态入口路由 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（以 DApp Browser 代替 Ecology 路由） |
| 16.2 | DBK Chain Home | `Ecology/dbk-chain/pages/Home/` | DBK Chain 首页 | ❌ |
| 16.3 | DBK Bridge | `Ecology/dbk-chain/pages/Bridge/` | DBK Chain 跨链桥 | ❌ |
| 16.4 | DBK MintNFT | `Ecology/dbk-chain/pages/MintNFT/` | DBK Chain 铸造NFT | ❌ |
| 16.5 | Sonic Home | `Ecology/sonic/pages/Home/` | Sonic 首页 | ❌ |
| 16.6 | Sonic Points | `Ecology/sonic/pages/Points/` | Sonic 积分页 | ❌ |
| 16.7 | Sonic迁移Banner | `Ecology/sonic/components/MigrationBanner.tsx` | Sonic 迁移提示 | ❌ |

---

## 十七、Rabby Points 积分（扩展端拆解 5 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 17.1 | RabbyPoints 主页 | `src/ui/views/RabbyPoints/index.tsx` | 积分主页 | ✅ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（RabbyPointsView） |
| 17.2 | TopBoard 排行榜 | `RabbyPoints/component/TopBoard.tsx` | 积分排行榜 | ❌ |
| 17.3 | ClaimItem 领取 | `RabbyPoints/component/ClaimItem.tsx` | 领取积分项 | ⚠️ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（Claim button + history，非列表式 ClaimItem） |
| 17.4 | CodeAndShare 分享 | `RabbyPoints/component/CodeAndShare.tsx` | 邀请码+分享 | ⚠️ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（Referral link 复制；可补系统分享） |
| 17.5 | VerifyAddressModal | `RabbyPoints/component/VerifyAddressModal.tsx` | 验证地址弹窗 | ❌ |

---

## 十八、Dapp 搜索（扩展端拆解 4 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 18.1 | DappSearch 主页 | `src/ui/views/DappSearch/index.tsx` | Dapp搜索主页 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（以 DApp Browser 代替） |
| 18.2 | DappCard | `DappSearch/components/DappCard.tsx` | Dapp卡片 | ⚠️ `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（PopularDApps 网格） |
| 18.3 | DappFavoriteList | `DappSearch/components/DappFavoriteList.tsx` | 收藏Dapp列表 | ❌（Bookmark 状态存在但未实现列表 UI） |
| 18.4 | DappSearchResult | `DappSearch/components/DappSearchResult.tsx` | 搜索结果展示 | ❌ |

---

## 十九、其他独立功能（扩展端拆解 6 项；iOS 对照逐条回填）

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 19.1 | ConnectedSites | `src/ui/views/ConnectedSites/` | 已连接站点管理 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（ConnectedSitesView；连接数据未完全贯通） |
| 19.2 | ChainList 链列表 | `src/ui/views/ChainList/` | 支持的链列表展示 | ✅ `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（ChainListView） |
| 19.3 | CustomRPC | `src/ui/views/CustomRPC/` | 自定义RPC(添加/编辑) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（CustomRPCView）+ `mobile/ios/RabbyMobile/Core/CustomRPCManager.swift` |
| 19.4 | CustomTestnet | `src/ui/views/CustomTestnet/` | 自定义测试网(添加/编辑/从ChainList添加) | ✅ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（CustomTestnetView）+ `mobile/ios/RabbyMobile/Core/CustomTestnetManager.swift` |
| 19.5 | AdvancedSettings | `src/ui/views/AdvanceSettings/` | 高级设置 | ⚠️ `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（AdvancedSettingsView） |
| 19.6 | MetamaskModeDapps | `src/ui/views/MetamaskModeDapps/` | MetaMask模式Dapp(引导+列表) | ❌ |

---

## 二十、核心 UI 组件库（扩展端拆解 28 组件；iOS 不做 1:1 时可忽略）

| # | 组件 | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 20.1 | ChainSelector | `src/ui/component/ChainSelector/` | 链选择器 | ❌ |
| 20.2 | TokenSelector | `src/ui/component/TokenSelector/` | 代币搜索+选择 | ❌ |
| 20.3 | TokenSelect | `src/ui/component/TokenSelect/` | 代币下拉选择 | ❌ |
| 20.4 | TokenAmountInput | `src/ui/component/TokenAmountInput/` | 代币金额输入框 | ❌ |
| 20.5 | TokenWithChain | `src/ui/component/TokenWithChain/` | 代币+链图标组合 | ❌ |
| 20.6 | TokenChart | `src/ui/component/TokenChart/` | 代币价格图表 | ❌ |
| 20.7 | AccountSelector | `src/ui/component/AccountSelector/` | 账户选择器 | ❌ |
| 20.8 | AccountSelectDrawer | `src/ui/component/AccountSelectDrawer/` | 账户选择抽屉 | ❌ |
| 20.9 | AddressViewer | `src/ui/component/AddressViewer/` | 地址查看器(缩略显示) | ❌ |
| 20.10 | NameAndAddress | `src/ui/component/NameAndAddress/` | 名称+地址 | ❌ |
| 20.11 | ChainIcon | `src/ui/component/ChainIcon.tsx` | 链图标 | ❌ |
| 20.12 | QRCodeReader | `src/ui/component/QRCodeReader/` | 二维码扫描器 | ❌ |
| 20.13 | MiniSignV2 | `src/ui/component/MiniSignV2/` | 迷你签名面板 | ❌ |
| 20.14 | TxHistory | `src/ui/component/TxHistory/` | 交易历史组件 | ❌ |
| 20.15 | ThemeMode | `src/ui/component/ThemeMode/` | 主题模式(ThemeIcon) | ❌ |
| 20.16 | ConnectStatus | `src/ui/component/ConnectStatus/` | 连接状态指示器 | ❌ |
| 20.17 | WalletConnect | `src/ui/component/WalletConnect/` | WalletConnect组件 | ❌ |
| 20.18 | Whitelist | `src/ui/component/Whitelist/` | 白名单管理组件(含密码弹窗) | ❌ |
| 20.19 | Contact | `src/ui/component/Contact/` | 联系人组件 | ❌ |
| 20.20 | RateModal | `src/ui/component/RateModal/` | 评分引导弹窗 | ❌ |
| 20.21 | Popup/Modal | `src/ui/component/Popup/` + `Modal/` | 弹窗/对话框 | ❌ |
| 20.22 | PageHeader | `src/ui/component/PageHeader/` | 页面头部导航 | ❌ |
| 20.23 | Navbar | `src/ui/component/Navbar/` | 导航栏 | ❌ |
| 20.24 | Loading/Spin | `src/ui/component/Loading/` + `Spin.tsx` | 加载动画 | ❌ |
| 20.25 | AddressRiskAlert | `src/ui/component/AddressRiskAlert/` | 地址风险告警 | ❌ |
| 20.26 | CexSelect | `src/ui/component/CexSelect/` | 中心化交易所选择 | ❌ |
| 20.27 | WordsMatrix | `src/ui/component/WordsMatrix/` | 助记词矩阵展示 | ❌ |
| 20.28 | StrayPage | `src/ui/component/StrayPage/` | 独立页面容器 | ❌ |

---

## 二十一、核心 Hooks（扩展端拆解 40+；iOS 不适用）

| # | Hook | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 21.1 | useAccounts | `src/ui/hooks/useAccounts.ts` | 账户列表 | ❌ |
| 21.2 | useCurrentBalance | `src/ui/hooks/useCurrentBalance.ts` | 当前余额 | ❌ |
| 21.3 | useChain | `src/ui/hooks/useChain.ts` | 链信息 | ❌ |
| 21.4 | useContact | `src/ui/hooks/useContact.ts` | 联系人 | ❌ |
| 21.5 | useSearchToken | `src/ui/hooks/useSearchToken.ts` | 代币搜索 | ❌ |
| 21.6 | useSortTokens | `src/ui/hooks/useSortTokens.ts` | 代币排序 | ❌ |
| 21.7 | useTokenInfo | `src/ui/hooks/useTokenInfo.ts` | 代币信息 | ❌ |
| 21.8 | useAddressInfo | `src/ui/hooks/useAddressInfo.ts` | 地址信息 | ❌ |
| 21.9 | useAddressRisk | `src/ui/hooks/useAddressRisk.ts` | 地址风险 | ❌ |
| 21.10 | useBalanceChange | `src/ui/hooks/useBalanceChange.ts` | 余额变化 | ❌ |
| 21.11 | useApprovalDangerCount | `src/ui/hooks/useApprovalDangerCount.ts` | 授权风险数 | ❌ |
| 21.12 | useGnosisNetworks | `src/ui/hooks/useGnosisNetworks.ts` | Gnosis网络 | ❌ |
| 21.13 | useGnosisPendingCount | `src/ui/hooks/useGnosisPendingCount.ts` | Gnosis待处理数 | ❌ |
| 21.14 | useGnosisPendingTxs | `src/ui/hooks/useGnosisPendingTxs.ts` | Gnosis待处理交易 | ❌ |
| 21.15 | useGnosisSafeInfo | `src/ui/hooks/useGnosisSafeInfo.ts` | Gnosis Safe信息 | ❌ |
| 21.16 | useSigner | `src/ui/hooks/useSigner.tsx` | 签名者 | ❌ |
| 21.17 | useTypedDataSigner | `src/ui/hooks/useTypedDataSigner.ts` | TypedData签名者 | ❌ |
| 21.18 | useNFTListingSigner | `src/ui/hooks/useNFTListingSigner.ts` | NFT上架签名 | ❌ |
| 21.19 | usePreference | `src/ui/hooks/usePreference.ts` | 用户偏好 | ❌ |
| 21.20 | useDeleteHdOrPrivateKey | `src/ui/hooks/useDeleteHdOrPrivateKeyringAddress.tsx` | 删除HD/私钥地址 | ❌ |
| 21.21 | useTypingMnemonics | `src/ui/hooks/useTypingMnemonics.ts` | 助记词输入 | ❌ |
| 21.22 | useParseAddress | `src/ui/hooks/useParseAddress.ts` | 地址解析(ENS等) | ❌ |
| 21.23 | useAppChain | `src/ui/hooks/useAppChain.ts` | 应用链状态 | ❌ |
| 21.24 | useBrandIcon | `src/ui/hooks/useBrandIcon.ts` | 品牌图标 | ❌ |
| 21.25+ | 其他15+ hooks | `src/ui/hooks/` | 事件监听/防抖/挂载等 | ❌ |

---

## 二十二、后台服务层（扩展端拆解 30+；iOS 对照逐条回填）

| # | 服务 | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 22.1 | Keyring 密钥管理 | `src/background/service/keyring/` | HD/Simple/Hardware 密钥环 | ⚠️ `mobile/ios/RabbyMobile/Core/KeyringManager.swift`（派生/签名 correctness 见 0.3） |
| 22.2 | OpenAPI | `src/background/service/openapi.ts` | Rabby API 客户端 | ✅ `mobile/ios/RabbyMobile/Core/OpenAPIService.swift` |
| 22.3 | Swap 服务 | `src/background/service/swap.ts` | DEX Swap 状态管理 | ⚠️ `mobile/ios/RabbyMobile/Core/SwapManager.swift`（未完成闭环） |
| 22.4 | Bridge 服务 | `src/background/service/bridge.ts` | 跨链桥状态管理 | ⚠️ `mobile/ios/RabbyMobile/Core/BridgeManager.swift`（未完成闭环） |
| 22.5 | TransactionHistory | `src/background/service/transactionHistory.ts` | 交易历史存储 | ⚠️ `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift` |
| 22.6 | TransactionBroadcastWatcher | `src/background/service/transactionBroadcastWatcher.ts` | 交易广播监听 | ✅ `mobile/ios/RabbyMobile/Core/TransactionBroadcastWatcherManager.swift` |
| 22.7 | TransactionWatcher | `src/background/service/transactionWatcher.ts` | 交易状态监听 | ✅ `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift` |
| 22.8 | Transactions | `src/background/service/transactions.ts` | 交易管理 | ⚠️ `mobile/ios/RabbyMobile/Core/TransactionManager.swift` |
| 22.9 | SecurityEngine | `src/background/service/securityEngine.ts` | 安全规则引擎 | ⚠️ `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift`（规则体系较简化） |
| 22.10 | Permission | `src/background/service/permission.ts` | Dapp权限管理 | ⚠️ `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`（DAppPermissionManager） |
| 22.11 | Preference | `src/background/service/preference.ts` | 用户偏好设置 | ✅ `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` |
| 22.12 | Whitelist | `src/background/service/whitelist.ts` | 白名单管理 | ✅ `mobile/ios/RabbyMobile/Core/WhitelistManager.swift` |
| 22.13 | ContactBook | `src/background/service/contactBook.ts` | 联系人管理 | ✅ `mobile/ios/RabbyMobile/Core/ContactBookManager.swift` |
| 22.14 | GasAccount | `src/background/service/gasAccount.ts` | Gas代付服务 | ⚠️ `mobile/ios/RabbyMobile/Core/GasAccountManager.swift` |
| 22.15 | Perps | `src/background/service/perps.ts` | 合约交易服务 | ⚠️ `mobile/ios/RabbyMobile/Core/PerpsManager.swift`（TODO 未对接） |
| 22.16 | Lending | `src/background/service/lending.ts` | 借贷服务 | ⚠️ `mobile/ios/RabbyMobile/Core/LendingManager.swift`（读 OpenAPI，交易侧未做） |
| 22.17 | RPC | `src/background/service/rpc.ts` | RPC管理 | ✅ `mobile/ios/RabbyMobile/Core/NetworkManager.swift` + `mobile/ios/RabbyMobile/Core/CustomRPCManager.swift` |
| 22.18 | AutoLock | `src/background/service/autoLock.ts` | 自动锁定服务 | ✅ `mobile/ios/RabbyMobile/Core/AutoLockManager.swift` |
| 22.19 | SignTextHistory | `src/background/service/signTextHistory.ts` | 签名文本历史 | ✅ `mobile/ios/RabbyMobile/Core/SignHistoryManager.swift` |
| 22.20 | RabbyPoints | `src/background/service/rabbyPoints.ts` | 积分服务 | ✅ `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift` |
| 22.21 | i18n | `src/background/service/i18n.ts` | 国际化服务 | ⚠️ `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（I18nManager；资源缺失见 0.4） |
| 22.22 | Session | `src/background/service/session.ts` | 会话管理 | ⚠️ `mobile/ios/RabbyMobile/Core/WatchGnosisSessionKeyrings.swift`（SessionManager） |
| 22.23 | Notification | `src/background/service/notification.ts` | 通知服务 | ⚠️ `mobile/ios/RabbyMobile/Core/NotificationManager.swift`（本地通知为主） |
| 22.24 | PageStateCache | `src/background/service/pageStateCache.ts` | 页面状态缓存 | ❌ |
| 22.25 | CustomTestnet | `src/background/service/customTestnet.ts` | 自定义测试网服务 | ✅ `mobile/ios/RabbyMobile/Core/CustomTestnetManager.swift` |
| 22.26 | OfflineChain | `src/background/service/offlineChain.ts` | 离线链检测 | ❌ |
| 22.27 | SyncChain | `src/background/service/syncChain.ts` | 链同步服务 | ⚠️ `mobile/ios/RabbyMobile/Core/SyncChainManager.swift`（链同步策略需核对） |
| 22.28 | Widget | `src/background/service/widget.ts` | Widget 管理 | ❌ |
| 22.29 | UserGuide | `src/background/service/userGuide.ts` | 用户引导状态 | ⚠️ `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（UserGuideManager；未接入 UI） |
| 22.30 | Misc | `src/background/service/misc.ts` | 杂项服务 | ⚠️ `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（含部分杂项状态） |

---

## 二十三、CommonPopup 资产弹窗模块（扩展端拆解 22 项；iOS 可选择性对齐） — 验证补充

> **重大遗漏**: 该模块约 72 个文件, ~10,438 行代码，是 Dashboard 资产展示的核心弹窗系统

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 23.1 | CommonPopup 主入口 | `src/ui/views/CommonPopup/index.tsx` | 全局弹窗容器 | ⚠️（iOS 以 SwiftUI `sheet`/`NavigationView` 组织；暂无统一 PopupHost） |
| 23.2 | AssetList 资产列表 | `CommonPopup/AssetList/` | 资产列表主模块 | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（资产页） |
| 23.3 | TokenList 代币列表 | `CommonPopup/AssetList/TokenList.tsx` | 代币资产列表 | ✅ `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`（Token list） |
| 23.4 | ChainList 链列表 | `CommonPopup/AssetList/ChainList.tsx` | 链资产列表 | ✅ `mobile/ios/RabbyMobile/Views/Assets/ChainBalanceView.swift` + `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`（SwitchChainPopup） |
| 23.5 | ProtocolList 协议列表 | `CommonPopup/AssetList/ProtocolList.tsx` | DeFi 协议资产列表 | ✅ `mobile/ios/RabbyMobile/Views/Assets/ProtocolPositionView.swift` |
| 23.6 | Lending 借贷协议模板 | `CommonPopup/AssetList/Protocols/Lending.tsx` | 借贷协议展示 | ⚠️ `mobile/ios/RabbyMobile/Views/Assets/ProtocolPositionView.swift`（未按模板拆分） |
| 23.7 | Perpetuals 永续合约模板 | `CommonPopup/AssetList/Protocols/Perpetuals.tsx` | 永续合约展示 | ❌ |
| 23.8 | Vesting 归属协议模板 | `CommonPopup/AssetList/Protocols/Vesting.tsx` | 代币归属展示 | ❌ |
| 23.9 | Reward 奖励协议模板 | `CommonPopup/AssetList/Protocols/Reward.tsx` | 奖励展示 | ❌ |
| 23.10 | Locked 锁仓协议模板 | `CommonPopup/AssetList/Protocols/Locked.tsx` | 锁仓展示 | ❌ |
| 23.11 | Leveraged 杠杆协议模板 | `CommonPopup/AssetList/Protocols/Leveraged.tsx` | 杠杆展示 | ❌ |
| 23.12 | Insurance 保险协议模板 | `CommonPopup/AssetList/Protocols/Insurance.tsx` | 保险展示 | ❌ |
| 23.13 | Common 通用协议模板 | `CommonPopup/AssetList/Protocols/Common.tsx` | 通用DeFi展示 | ⚠️ `mobile/ios/RabbyMobile/Views/Assets/ProtocolPositionView.swift`（以 OpenAPI portfolio 数据为准） |
| 23.14 | 其他7个协议模板 | `CommonPopup/AssetList/Protocols/` | Deposit/Yield/OptionsSeller等 | ❌ |
| 23.15 | CustomAssetList | `CommonPopup/AssetList/CustomAssetList.tsx` | 自定义资产列表 | ⚠️ `mobile/ios/RabbyMobile/Views/Assets/AddCustomTokenView.swift` + `mobile/ios/RabbyMobile/Core/TokenManager.swift` |
| 23.16 | CustomTestnetAssetList | `CommonPopup/AssetList/CustomTestnetAssetList.tsx` | 测试网资产列表 | ⚠️ `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（CustomTestnetView；资产列表未对齐） |
| 23.17 | CancelApproval | `CommonPopup/CancelApproval/` | 取消授权弹窗 | ❌ |
| 23.18 | CancelConnect | `CommonPopup/CancelConnect/` | 取消连接弹窗 | ❌ |
| 23.19 | SwitchAddress | `CommonPopup/SwitchAddress/` | 切换地址弹窗 | ✅ `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`（SwitchAccountPopup） |
| 23.20 | SwitchChain | `CommonPopup/SwitchChain/` | 切换链弹窗 | ✅ `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`（SwitchChainPopup） |
| 23.21 | Ledger/Keystone/OneKey 权限 | `CommonPopup/Ledger/` + `Keystone/` + `OneKey/` | 硬件钱包权限弹窗 | ❌（iOS 暂无对应权限弹窗体系） |
| 23.22 | ImKeyPermission | `CommonPopup/ImKeyPermission/` | imKey 权限弹窗 | ❌ |

---

## 二十四、Desktop 桌面端模块（扩展端拆解 18 组；iOS 可忽略/后期选择性迁移） — 验证补充

> **注意**: 以下为桌面端(Desktop App)专用视图，共 ~63,000+ 行代码。iOS 可选择性迁移部分功能。

### 24.1 DesktopLending 借贷 (~77 文件)
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 24.1.1 | DesktopLending 主页 | `src/ui/views/DesktopLending/index.tsx` | 借贷主页 | ❌ |
| 24.1.2 | LendingRow (Supply/Borrow) | `DesktopLending/components/LendingRow/` | 供应/借贷行项 | ❌ |
| 24.1.3 | SummaryBar | `DesktopLending/components/SummaryBar/` | 借贷摘要栏(HF/净值) | ❌ |
| 24.1.4 | SupplyModal | `DesktopLending/components/SupplyModal/` | 存入弹窗 | ❌ |
| 24.1.5 | BorrowModal | `DesktopLending/components/BorrowModal/` | 借款弹窗 | ❌ |
| 24.1.6 | RepayModal | `DesktopLending/components/RepayModal/` | 还款弹窗 | ❌ |
| 24.1.7 | WithdrawModal | `DesktopLending/components/WithdrawModal/` | 提取弹窗 | ❌ |
| 24.1.8 | ManageEmodeModal | `DesktopLending/components/ManageEmodeModal/` | E-Mode管理 | ❌ |
| 24.1.9 | MarketSelector | `DesktopLending/components/MarketSelector/` | 市场选择器(Aave V3等) | ❌ |
| 24.1.10 | HealthFactor | `DesktopLending/components/HFDescription/` | 健康因子展示 | ❌ |

### 24.2 DesktopPerps 专业合约 (~70+ 文件)
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 24.2.1 | DesktopPerps 主页 | `src/ui/views/DesktopPerps/index.tsx` | 专业合约交易页 | ❌ |
| 24.2.2 | TradingPanel | `DesktopPerps/components/TradingPanel/` | 交易面板(Market/Limit/TWAP/Scale) | ❌ |
| 24.2.3 | ChartArea | `DesktopPerps/components/ChartArea/` | K线图区域 | ❌ |
| 24.2.4 | OrderBookTrades | `DesktopPerps/components/OrderBookTrades/` | 订单簿+成交记录 | ❌ |
| 24.2.5 | UserInfoHistory | `DesktopPerps/components/UserInfoHistory/` | 持仓/订单/历史/资金费率 | ❌ |

### 24.3 DesktopProfile 个人中心 (~30+ 文件)
| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 24.3.1 | DesktopProfile 主页 | `src/ui/views/DesktopProfile/index.tsx` | 桌面端个人中心 | ❌ |
| 24.3.2 | TransactionsTabPane | `DesktopProfile/components/TransactionsTabPane/` | 交易记录标签页 | ❌ |
| 24.3.3 | NFTTabPane | `DesktopProfile/components/NFTTabPane/` | NFT标签页(Listing/Offer) | ❌ |

---

## 二十五、遗漏视图/路由（扩展端拆解 5 项；iOS 对照待逐条回填） — 验证补充

| # | 子功能 | 扩展源码位置 | 说明 | iOS |
|---|--------|-------------|------|-----|
| 25.1 | SortHat 路由分发 | `src/ui/views/SortHat.tsx` | 根据 UI 类型(popup/notification/tab)分发路由 | ❌ |
| 25.2 | PreferMetamaskDapps | `src/ui/views/PreferMetamaskDapps/` | MetaMask偏好Dapp管理 | ❌ |
| 25.3 | QRCodeCheckerDetail | `src/ui/views/QRCodeCheckerDetail.tsx` | QR码验证详情 | ❌ |
| 25.4 | RequestDeBankTestnetGasToken | `src/ui/views/RequestDeBankTestnetGasToken/` | 测试网Gas水龙头 | ❌ |
| 25.5 | AddressManagement (切换) | `src/ui/views/AddressManagement/` | 地址切换页面(含排序) | ❌ |

---

## 二十六、遗漏 UI 组件（扩展端拆解 16 组件；iOS 对照待逐条回填） — 验证补充

| # | 组件 | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 26.1 | AccountSearchInput | `src/ui/component/AccountSearchInput/` | 账户搜索输入框 | ❌ |
| 26.2 | AddAddressOptions | `src/ui/component/AddAddressOptions/` | 添加地址选项 | ❌ |
| 26.3 | AddressList | `src/ui/component/AddressList/` | 地址列表组件 | ❌ |
| 26.4 | AuthenticationModal | `src/ui/component/AuthenticationModal/` | 认证/密码验证弹窗 | ❌ |
| 26.5 | Empty | `src/ui/component/Empty/` | 空状态展示 | ❌ |
| 26.6 | FallbackSiteLogo | `src/ui/component/FallbackSiteLogo/` | 站点Logo回退展示 | ❌ |
| 26.7 | FullscreenContainer | `src/ui/component/FullscreenContainer/` | 全屏容器 | ❌ |
| 26.8 | PortalHost | `src/ui/component/PortalHost/` | Portal宿主(弹窗挂载点) | ❌ |
| 26.9 | SendLike | `src/ui/component/SendLike/` | 发送相关组件(AddressInfoFrom/To/ToAddressCard/Slider) | ❌ |
| 26.10 | SignProcessButton | `src/ui/component/SignProcessButton.tsx` | 签名进度按钮 | ❌ |
| 26.11 | Signal | `src/ui/component/Signal.tsx` | 信号指示器 | ❌ |
| 26.12 | StrayFooter | `src/ui/component/StrayFooter.tsx` | 独立页脚 | ❌ |
| 26.13 | StrayHeader | `src/ui/component/StrayHeader.tsx` | 独立页头 | ❌ |
| 26.14 | ExternalSwapBridgeDappPopup | `src/ui/component/ExternalSwapBridgeDappPopup/` | 外部Swap/Bridge Dapp弹窗 | ❌ |
| 26.15 | CexSelect | `src/ui/component/CexSelect/` | 中心化交易所选择 | ❌ |
| 26.16 | RateModal | `src/ui/component/RateModal/` | 评分引导弹窗 | ❌ |

---

## 二十七、遗漏后台服务（扩展端拆解 4 项；iOS 对照待逐条回填） — 验证补充

| # | 服务 | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 27.1 | MetaMaskMode Service | `src/background/service/metamaskModeService.ts` | MetaMask兼容模式服务 | ⚠️ 可选（iOS `DAppBrowser` 可实现类似“需要 MetaMask 兼容模式”的站点列表逻辑） |
| 27.2 | InnerDappFrame Service | `src/background/service/innerDappFrame.ts` | 内嵌Dapp框架服务 | N/A（iOS 无 iframe/frame 概念） |
| 27.3 | HDKeyRingLastAddAddrTime | `src/background/service/HDKeyRingLastAddAddrTime.ts` | HD钱包最后添加地址时间 | ❌（iOS 未实现；如需与扩展一致的引导/提示可补） |
| 27.4 | UnTriggerTxCounter | `src/background/service/unTriggerTxCounter.ts` | 未触发交易计数器 | N/A（偏扩展统计/触发计数逻辑） |

---

## 二十八、遗漏 Hooks（扩展端拆解 8 项；iOS 不适用） — 验证补充

| # | Hook | 扩展源码位置 | 说明 | iOS |
|---|------|-------------|------|-----|
| 28.1 | useAccount (backgroundState) | `src/ui/hooks/backgroundState/useAccount.ts` | 当前账户状态 | N/A（iOS 无 React Hooks；用 ObservableObject/Combine 代替） |
| 28.2 | miniSignGasStore | `src/ui/hooks/miniSignGasStore.tsx` | 迷你签名Gas状态存储 | N/A |
| 28.3 | useEnterPassphraseModal | `src/ui/hooks/useEnterPassphraseModal.ts` | 输入密码短语弹窗 | N/A |
| 28.4 | useMiniApprovalDirectSign | `src/ui/hooks/useMiniApprovalDirectSign.tsx` | 迷你审批直接签名 | N/A |
| 28.5 | useGnosisPendingMessages | `src/ui/hooks/useGnosisPendingMessages.ts` | Gnosis待处理消息 | N/A |
| 28.6 | useSyncGnosisNetworks | `src/ui/hooks/useSyncGnonisNetworks.ts` | 同步Gnosis网络 | N/A |
| 28.7 | contextState | `src/ui/hooks/contextState.tsx` | 上下文状态管理 | N/A |
| 28.8 | useIframeBridge | `src/ui/hooks/useIframeBridge.ts` | iframe通信桥接 | N/A（iOS 用 WKWebView bridge/URLSession） |

---

## 总结统计（以本仓库 `mobile/ios/` 为准）

> 说明：本文件前半部分的「414+ 子功能」用于扩展端对标拆解；iOS 列已按本仓库 `mobile/ios/` 逐条回填（✅/⚠️/❌），用于快速盘点覆盖与缺口（20/21/25-28 等“组件/Hooks/遗漏项”仍可按需继续补齐）。

| 模块分类 | 扩展子功能数(参考) | iOS(本仓库) | iOS 对应实现 |
|---------|--------------------|------------|--------------|
| Dashboard 主页 | 16 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` |
| 发送/接收 | 12 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift` + `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` |
| DEX Swap | 14 | ⚠️ 骨架 | `mobile/ios/RabbyMobile/Core/SwapManager.swift` + `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift` |
| Bridge 跨链桥 | 12 | ⚠️ 骨架 | `mobile/ios/RabbyMobile/Core/BridgeManager.swift` + `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift` |
| Perps 合约交易 | 19 | ⚠️ 骨架 | `mobile/ios/RabbyMobile/Core/PerpsManager.swift` |
| GasAccount | 10 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Core/GasAccountManager.swift` + `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift` |
| 交易历史 | 8 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Core/TransactionManager.swift` + `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift` |
| NFT | 6 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Core/NFTManager.swift` + `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift` |
| 授权管理（查看/撤销） | 7 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（TokenApprovalView）+ `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`（NFTApprovalView） |
| 交易审批/签名引擎 | 54 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift` + `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift` + `mobile/ios/RabbyMobile/Core/EthereumUtils.swift` |
| 账户创建/导入 | 16 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Wallet/` + `mobile/ios/RabbyMobile/Views/Import/` |
| 新用户引导 | 14 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/RootView.swift`（OnboardingView）+ `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（UserGuideManager 未接 UI） |
| 硬件钱包 | 8 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Core/HardwareWallet/` + `mobile/ios/RabbyMobile/Views/HardwareWallet/LedgerConnectView.swift` |
| 多签/协议钱包 | 5 | ⚠️ 骨架 | `mobile/ios/RabbyMobile/Core/WatchGnosisSessionKeyrings.swift` |
| 设置/管理 | 20 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift` |
| Rabby Points | 5 | ✅ 基本可用 | `mobile/ios/RabbyMobile/Views/More/MiscViews.swift` |
| DApp 浏览器/生态 | 7/4 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift` |
| 后台服务层 | 30 | ⚠️ 部分实现 | `mobile/ios/RabbyMobile/Core/` |
| i18n/资源 | - | ❌ | locales/fonts/品牌资源待补 |

---

## iOS 适配需额外开发的功能（扩展没有 / 或需要原生化）

| # | 功能 | 说明 | 状态 | iOS 对应实现 |
|---|------|------|------|--------------|
| A1 | 生物识别 (Face ID / Touch ID) | 替代扩展的密码解锁 | ✅ | `mobile/ios/RabbyMobile/Core/BiometricAuthManager.swift` |
| A2 | 推送通知 | 交易状态推送(替代扩展的后台轮询) | ⚠️ | `mobile/ios/RabbyMobile/Core/NotificationManager.swift`（本地通知/注册 APNs，缺后端推送闭环） |
| A3 | 深度链接 (Deep Link) | WalletConnect/Dapp跳转 | ⚠️ | `mobile/ios/RabbyMobile/RabbyMobileApp.swift`（已处理 wc/rabbywallet scheme，但 WC pairing 未完成） |
| A4 | 硬件钱包蓝牙连接 | iOS通过BLE连接Ledger等(替代USB/WebHID) | ⚠️ | `mobile/ios/RabbyMobile/Core/HardwareWallet/BluetoothManager.swift` + `mobile/ios/RabbyMobile/Core/HardwareWallet/LedgerKeyring.swift` |
| A5 | Keychain 安全存储 | iOS Keychain替代浏览器本地存储 | ✅ | `mobile/ios/RabbyMobile/Core/StorageManager.swift` |
| A6 | App内浏览器 (DApp Browser) | 替代扩展的content-script注入 | ⚠️ | `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（provider/签名请求仍需补齐） |
| A7 | 相机扫码 | 原生相机扫描QR码 | ❌ | （当前仅二维码生成；需新增 AVCapture scanner） |
| A8 | 手势导航 | iOS原生手势(滑动返回等) | ✅ | 由 iOS 系统/SwiftUI `NavigationStack` 支持 |
| A9 | 离线签名 | 无网络时的签名能力 | ⚠️ | 已有签名能力，但需先修复 0.3 的派生/签名规则一致性问题 |
| A10 | Widget / App Clips | iOS桌面组件/轻应用 | ❌ | （未实现） |

---

> **最终结论（2026-02-13 更新）**: iOS 端已存在可运行的 SwiftUI 钱包骨架与部分功能页，但与扩展一致性的 P0 问题（BIP44 派生、EIP-155/typed-tx v 值、EIP-712、WalletConnect、EIP-1559 fee 等）未修复前，整体仍处于“可演示但不可对外发布”的阶段。建议先完成本文 **0.3 P0 修复** + **0.4 资源补齐**，再按 Phase 1-3 补齐导入/资产/发送闭环，最后再追求 CommonPopup/桌面端等 1:1 细节。

---
---

# iOS 开发清单 — 分阶段任务排期

> **扩展钱包源码量**: UI 层 ~232,000 行, 后台服务 ~26,000 行, 组件库 ~24,000 行, Desktop 桌面端 ~63,000 行 (⭐验证补充)
> **预计 iOS 端总代码量**: ~180,000 行 (去除浏览器扩展特有逻辑，新增 iOS 原生适配; 不含可选 Desktop 功能)

---

## 阶段〇：项目基建 (Phase 0)

> 所有后续开发的基础，必须最先完成

### P0-1 项目架构搭建
- [x] 确定技术栈: **SwiftUI 原生**（本仓库已落地）— `mobile/ios/RabbyMobile/`
- [x] 初始化 iOS 项目工程，配置 Xcode / CocoaPods — `mobile/ios/RabbyMobile.xcodeproj` + `mobile/ios/Podfile`
- [ ] 配置 CI/CD 管线 (TestFlight 自动打包)
- [x] 接入 SwiftLint（Debug）— `mobile/ios/Podfile`
- [ ] 接入 Sentry / Crash 监控（iOS 原生）

### P0-2 共享层迁移
- [ ] 迁移 `packages/shared` 类型定义 (Chain, Token, Account, NFT, SwapQuote 等)
- [ ] 迁移 `packages/shared` 常量 (KEYRING_TYPE, HARDWARE_BRANDS, RPC_METHODS 等)
- [ ] 迁移 `packages/shared` 工具函数 (address.ts, string.ts, scan.ts, url.ts)
- [ ] 适配 `packages/ui` 主题系统 (lightTheme/darkTheme → iOS 适配)

### P0-3 核心服务层搭建
- [x] 搭建 API Client 层 — 对接 Rabby OpenAPI — `mobile/ios/RabbyMobile/Core/OpenAPIService.swift`
- [x] 搭建本地存储方案 — iOS Keychain (敏感数据) + UserDefaults(偏好) — `mobile/ios/RabbyMobile/Core/StorageManager.swift`
- [x] 搭建加密/签名基础能力（⚠️ correctness 见 0.3）— `mobile/ios/RabbyMobile/Utils/Keccak256.swift` + `mobile/ios/RabbyMobile/Utils/Secp256k1Helper.swift`
- [x] 搭建 i18n 框架（⚠️ 资源缺失见 0.4）— `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`
- [x] 搭建全局状态管理（ObservableObject/Combine）— `mobile/ios/RabbyMobile/Core/` + `mobile/ios/RabbyMobile/Views/`

### P0-4 基础 UI 组件库
- [x] Navigation / Header（NavigationView + Toolbar）— iOS 原生（各页面 `NavigationView { ... }`）
- [x] 底部导航 TabBar（Assets/Swap/DApps/History/Settings）— `mobile/ios/RabbyMobile/Views/RootView.swift`
- [x] Loading / Spin（ProgressView）— iOS 原生
- [x] Sheet / Modal / Alert（.sheet / .alert）— iOS 原生
- [x] ThemeMode（Light/Dark/System）— `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` + `mobile/ios/RabbyMobile/RabbyMobileApp.swift` + `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] 地址缩略显示/复制（多处已实现）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` + `mobile/ios/RabbyMobile/Views/AddressDetail/AddressDetailView.swift`
- [x] 远程图标加载与缓存（Token/Chain/NFT）— `mobile/ios/RabbyMobile/Utils/ImageCacheManager.swift` + `mobile/ios/RabbyMobile/Utils/CryptoIconProvider.swift`
- [ ] 离线资源兜底（品牌/空状态/硬件钱包/链图标/token 兜底）— 见 0.4（需补 `mobile/ios/RabbyMobile/Images.xcassets`）

**Phase 0 产出**: 可编译运行的 iOS App（Onboarding/Unlock/MainTab）+ Core services（Storage/OpenAPI/Chain/RPC）+ 基础页面骨架

---

## 阶段一：账户系统 (Phase 1) — 最高优先级

> 钱包的入口，没有账户系统其他功能均无法使用
> 参考代码量: 新用户引导 ~3,400 行, Keyring ~6,200 行, 偏好设置 ~965 行

### P1-1 密钥管理核心 (Keyring Service)
- [x] HD Keyring — 助记词生成/派生地址 — `mobile/ios/RabbyMobile/Core/KeyringManager.swift`（⚠️ BIP44 correctness 见 0.3）
- [x] Simple Keyring — 私钥导入 — `mobile/ios/RabbyMobile/Core/KeyringManager.swift`
- [x] Watch Address Keyring — 观察地址 — `mobile/ios/RabbyMobile/Core/WatchGnosisSessionKeyrings.swift`
- [x] 密码加密存储 — AES-GCM + PBKDF2 — `mobile/ios/RabbyMobile/Core/StorageManager.swift`
- [x] iOS Keychain 安全存储 — 替代 chrome.storage.local — `mobile/ios/RabbyMobile/Core/StorageManager.swift`
- [x] Preference 服务（主题/语言/当前账户/隐藏地址等）— `mobile/ios/RabbyMobile/Core/PreferenceManager.swift`
- [ ] Keystore(JSON) 导入（scrypt/pbkdf2 + AES-128-CTR）— `mobile/ios/RabbyMobile/Core/KeyringManager.swift`
- [ ] 补齐更多 keyring 类型接入（Ledger/Gnosis/WC 等）— `mobile/ios/RabbyMobile/Core/KeyringManager.swift`

### P1-2 欢迎/注册流程
- [x] Onboarding/Welcome（创建/导入入口）— `mobile/ios/RabbyMobile/Views/RootView.swift`
- [x] CreateWallet（设置密码 + 生成/备份/验证助记词）— `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift`
- [x] ImportWallet（助记词/私钥导入）— `mobile/ios/RabbyMobile/Views/Wallet/ImportWalletView.swift`
- [ ] Watch-only 引导入口（Onboarding 按钮目前未接入流程）— `mobile/ios/RabbyMobile/Views/RootView.swift`

### P1-3 新用户引导 (New User Import)
- [x] 创建助记词 + 备份验证 — `mobile/ios/RabbyMobile/Views/Wallet/CreateWalletView.swift`
- [x] 导入方式选择（seed/privateKey/watch）— `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`
- [x] 选择派生地址 — `mobile/ios/RabbyMobile/Views/Import/SelectAddressView.swift`
- [x] 导入成功页（从 seed 添加地址）— `mobile/ios/RabbyMobile/Views/Import/ImportSuccessAddFromSeedView.swift`

### P1-4 老用户导入流程
- [x] 导入私钥/助记词 — `mobile/ios/RabbyMobile/Views/Wallet/ImportWalletView.swift`
- [x] 导入/添加地址入口（seed/privateKey/watch）— `mobile/ios/RabbyMobile/Views/Import/ImportOptionsView.swift`
- [x] 选择地址（派生列表）— `mobile/ios/RabbyMobile/Views/Import/SelectAddressView.swift`
- [ ] 导入 JSON Keystore — `mobile/ios/RabbyMobile/Core/KeyringManager.swift`（未实现）

### P1-5 解锁/锁定
- [x] UnlockView（密码解锁）— `mobile/ios/RabbyMobile/Views/RootView.swift`
- [x] Face ID / Touch ID 生物识别解锁 — `mobile/ios/RabbyMobile/Core/BiometricAuthManager.swift`
- [x] ForgotPasswordView — `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`
- [x] AutoLock 自动锁定服务 — `mobile/ios/RabbyMobile/Core/AutoLockManager.swift`

**Phase 1 产出**: 用户可创建/导入/解锁钱包，安全存储密钥（⚠️ 上线前需先完成 0.3 P0 修复）

---

## 阶段二：Dashboard 主页 (Phase 2)

> 钱包主界面，用户打开 App 第一个看到的页面
> 参考代码量: Dashboard ~12,235 行

### P2-1 Dashboard 核心
- [x] 资产首页主入口（iOS 使用 AssetsView，而非 Dashboard TS 结构）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] Header（账户名/地址/复制/链选择）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 账户切换弹窗（SwitchAccountPopup）— `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`
- [x] 切换链弹窗（SwitchChainPopup）— `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`
- [ ] 连接状态指示器（Dashboard Header 级别）— iOS 暂未做独立组件（可基于 `DAppPermissionManager` 补齐）

### P2-2 资产展示
- [x] 总资产展示（Total Balance）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 资产曲线（BalanceCurveView）— `mobile/ios/RabbyMobile/Views/Assets/BalanceCurveView.swift`
- [x] 各链资产分布（ChainBalanceView）— `mobile/ios/RabbyMobile/Views/Assets/ChainBalanceView.swift`
- [x] 代币列表 + 搜索 + 详情页 — `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift` + `mobile/ios/RabbyMobile/Views/Assets/TokenDetailView.swift`
- [x] DeFi 仓位列表（ProtocolPositionView）— `mobile/ios/RabbyMobile/Views/Assets/ProtocolPositionView.swift`
- [x] NFT 资产展示（NFTGalleryView/NFTDetailView）— `mobile/ios/RabbyMobile/Views/Assets/NFTGalleryView.swift`
- [ ] TokenChart（代币价格图表）— iOS 暂无对标组件

### P2-3 功能面板
- [x] 快捷操作（Send/Receive/Import/SwitchChain/Pending badge）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 底部主导航（Assets/Swap/DApps/History/Settings）— `mobile/ios/RabbyMobile/Views/RootView.swift`
- [ ] 可拖拽排序的入口网格（DashboardPanel 1:1）— iOS 暂未实现

### P2-4 Dashboard 辅助模块
- [x] GasPriceBar（实时 Gas 价格）— `mobile/ios/RabbyMobile/Views/Assets/GasPriceBarView.swift`
- [x] Token 详情（页面式，不是 popup）— `mobile/ios/RabbyMobile/Views/Assets/TokenDetailView.swift`
- [x] PendingTxs 待处理交易提示（badge）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 交易审批页风险提示（Security Check）— `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`
- [ ] Dashboard 级别“安全状态”独立组件 — iOS 暂未对齐扩展结构

**Phase 2 产出**: 用户可查看资产总额、各链余额、代币列表、Gas 价格（⚠️ 仍需先完成 0.3 P0 修复，确保派生/签名/fee 规则正确）

### P2-5 CommonPopup 资产弹窗系统 ⭐验证补充
> 扩展端 CommonPopup 是“桌面端全局弹窗容器”。iOS 端当前以 **页面/Sheet** 为主，不建议 1:1 复刻；如需对齐交互，再考虑做统一的 PopupHost。
- [x] TokenList（代币列表）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] ChainList（各链资产/链切换）— `mobile/ios/RabbyMobile/Views/Assets/ChainBalanceView.swift` + `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`
- [x] ProtocolList（DeFi 协议资产）— `mobile/ios/RabbyMobile/Views/Assets/ProtocolPositionView.swift`
- [x] SwitchAddress（切换地址弹窗）— `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`
- [ ] CancelApproval/CancelConnect 等“弹窗体系”能力 — iOS 暂未实现
- [ ] 硬件钱包权限弹窗（Ledger/Keystone/OneKey/ImKey）— iOS 暂未实现（仅有 Ledger 连接页骨架）

---

## 阶段三：发送/接收 (Phase 3)

> 钱包最核心的交易功能
> 参考代码量: SendToken ~3,304 行

### P3-1 接收
- [x] ReceiveView（QR码 + 地址 + 复制）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [x] 二维码生成（CoreImage）— `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`
- [ ] 相机扫码（Scan QR）— `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（入口已存在，需补 scanner）

### P3-2 发送代币
- [x] SendTokenView（含代币选择/联系人/白名单/Gas估算）— `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`
- [x] TokenSelectorSheet（选择代币）— `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`
- [x] ContactPickerSheet（选择联系人地址）— `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`
- [x] MaxButton（最大金额）— `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`
- [ ] ReserveGas / PreExec 解释（扩展特性）— iOS 暂未对齐

### P3-3 地址选择
- [x] 联系人地址选择（ContactPickerSheet）— `mobile/ios/RabbyMobile/Views/Send/SendTokenView.swift`
- [x] ContactBookManager（联系人服务）— `mobile/ios/RabbyMobile/Core/ContactBookManager.swift`
- [x] 地址风险基础校验（whitelist/黑名单规则）— `mobile/ios/RabbyMobile/Core/WhitelistManager.swift` + `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift`
- [ ] ENS/地址解析（对标 useParseAddress）— iOS 暂未实现

### P3-4 白名单
- [x] WhitelistInputView（白名单输入 UI）— `mobile/ios/RabbyMobile/Views/Settings/WhitelistInputView.swift`
- [x] WhitelistManager（白名单服务）— `mobile/ios/RabbyMobile/Core/WhitelistManager.swift`

### P3-5 发送 NFT
- [x] SendNFTView（ERC721/1155 发送 UI）— `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift`
- [ ] ERC1155 transfer calldata 完整编码（当前省略实现）— `mobile/ios/RabbyMobile/Core/NFTManager.swift`

### P3-6 交易核心服务
- [x] TransactionManager（交易构建/发送/加速/取消/本地 pending/completed）— `mobile/ios/RabbyMobile/Core/TransactionManager.swift`
- [x] TransactionHistoryManager — `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift`
- [x] TransactionWatcherManager — `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`
- [x] TransactionBroadcastWatcherManager — `mobile/ios/RabbyMobile/Core/TransactionBroadcastWatcherManager.swift`
- [ ] EIP-1559 fee 取值与签名规则修复（见 0.3）— `mobile/ios/RabbyMobile/Core/TransactionManager.swift`

**Phase 3 产出**: 用户可发送/接收代币和NFT，管理联系人和白名单（⚠️ 上线前需先完成 0.3 P0 修复）

---

## 阶段四：交易审批/签名引擎 (Phase 4) — 最复杂模块

> 所有交易操作的核心，所有 DeFi 功能依赖此模块
> 扩展端参考：Approval ~38,648 行（本阶段“是否可上线”取决于 correctness 与请求覆盖）

### P4-1 iOS 交易审批（SignTx）
- [x] TransactionApprovalView（交易审批页 + Gas 设置 + 基础风险列表）— `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`
- [x] SecurityEngineManager（交易风险检查）— `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift`
- [ ] BalanceChange 余额变化预览（对齐扩展 BalanceChange 体验）— iOS 暂无（需对接 OpenAPI 或本地解析）
- [ ] Action 解析（Send/Approve/Swap/Bridge/NFT 等“读得懂的交易摘要”）— iOS 暂无（当前以基础字段展示为主）

### P4-2 iOS 消息签名（personal_sign）
- [ ] MessageApprovalView（SignText）— iOS 暂无（需新增 View）
- [ ] DAppBrowser personal_sign 请求处理 — `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`（`handleSignMessage` 为空）
- [ ] 签名历史写入（从 DAppBrowser/WC 写入记录）— `mobile/ios/RabbyMobile/Core/SignHistoryManager.swift`

### P4-3 iOS TypedData 签名（EIP-712）
- [ ] TypedDataApprovalView（SignTypedData）— iOS 暂无（需新增 View）
- [ ] EIP-712 TypedData 编码实现 — `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`（notImplemented）
- [ ] TypedData 可读化预览（domain/primaryType/fields）— iOS 暂无

### P4-4 correctness（上线阻断，必须先修）
- [ ] BIP44 子私钥派生修复 — `mobile/ios/RabbyMobile/Core/BIP44.swift`
- [ ] EIP-155 / typed-tx `v` 值修复 — `mobile/ios/RabbyMobile/Utils/Secp256k1Helper.swift` + `mobile/ios/RabbyMobile/Core/EthereumUtils.swift`
- [ ] EIP-1559 fee 计算修复（baseFee 取值）— `mobile/ios/RabbyMobile/Core/TransactionManager.swift`
- [ ] Tx 构建 nonce/gas/fee 统一与校验 — `mobile/ios/RabbyMobile/Core/TransactionManager.swift` + `mobile/ios/RabbyMobile/Core/NetworkManager.swift`

### P4-5 DApp 权限/请求类型（Connect/SwitchChain/AddChain 等）
- [x] DAppPermissionManager 数据结构 — `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`
- [x] ConnectedSites 管理页 — `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（ConnectedSitesView）
- [ ] DApp connect 授权弹窗（允许/拒绝/记住站点）— iOS 暂无（目前 `eth_requestAccounts` 自动返回账户）
- [ ] wallet_addEthereumChain / wallet_watchAsset 等请求 — iOS 暂未支持
- [x] wallet_switchEthereumChain（切链）— `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`

**Phase 4 产出**: iOS 端可完整处理 DApp/WalletConnect 的交易 + 消息签名请求（含安全检查）并正确签名/广播（⚠️ 依赖 0.3 P0 修复）

---

## 阶段五：DEX Swap + Bridge (Phase 5)

> DeFi 核心交易功能
> 参考代码量: Swap ~7,097 行, Bridge ~6,195 行

### P5-1 Swap 兑换
- [x] SwapView（UI 骨架）— `mobile/ios/RabbyMobile/Views/Swap/SwapView.swift`（⚠️ 缺 token selector/sheet 与 slippage sheet）
- [x] SwapManager（quotes/approve/execute）— `mobile/ios/RabbyMobile/Core/SwapManager.swift`（⚠️ `user_address` 未传、nonce/gas 默认值需修）
- [ ] TokenSelectorSheet（From/To 代币选择 + 搜索 + 最近使用）— iOS 暂无（建议基于 `mobile/ios/RabbyMobile/Core/TokenManager.swift`）
- [ ] Slippage 设置 Sheet（Auto/自定义）— iOS 暂无（SwapView 已有 `showSlippageSheet` 状态）
- [ ] Approve → Swap 两步流程（needApprove handling）— iOS 暂未贯通（SwapManager 已有 `approveToken` + `needApproval` error）
- [ ] Swap tx 构建/签名/广播闭环（nonce/fee/EIP1559）— 依赖 Phase 4 correctness（0.3）— `mobile/ios/RabbyMobile/Core/SwapManager.swift` + `mobile/ios/RabbyMobile/Core/TransactionManager.swift`
- [ ] Swap 历史/待处理在 Swap 页展示（对齐扩展体验）— 可复用 `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`

### P5-2 Bridge 跨链桥
- [x] BridgeView（UI 骨架）— `mobile/ios/RabbyMobile/Views/Bridge/BridgeView.swift`
- [x] BridgeManager（quotes/status）— `mobile/ios/RabbyMobile/Core/BridgeManager.swift`（⚠️ `executeBridge` 签名/发送未完成）
- [ ] Bridge 执行闭环（approve → buildTx → sign → send）— `mobile/ios/RabbyMobile/Core/BridgeManager.swift`
- [ ] Bridge 历史/状态跟踪闭环（post + status polling/confirm）— `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift` + `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`
- [ ] Bridge 聚合器筛选 UI（selectedAggregators）— `mobile/ios/RabbyMobile/Core/BridgeManager.swift`（UI 未实现）

**Phase 5 产出**: 用户可进行 DEX Swap 兑换和跨链桥转账（⚠️ 依赖 Phase 4 correctness + approval 请求覆盖）

---

## 阶段六：交易历史 + 授权管理 (Phase 6)

> 参考代码量: History ~713 行, TransactionHistory ~大量, TokenApproval ~527 行, NFTApproval ~644 行

### P6-1 交易历史
- [x] TransactionHistoryView（列表 + 过滤 tabs）— `mobile/ios/RabbyMobile/Views/History/TransactionHistoryView.swift`
- [x] TransactionHistoryManager（本地历史/分组/Swap&Bridge 子历史）— `mobile/ios/RabbyMobile/Core/TransactionHistoryManager.swift`
- [ ] 过滤诈骗交易（is_scam）— iOS 暂无（扩展端有开关）
- [ ] Tx 详情页（含 Explorer/Cancel/SpeedUp/Explain）— iOS 暂无（核心方法在 `mobile/ios/RabbyMobile/Core/TransactionManager.swift`）
- [ ] Cancel/SpeedUp UI（对标 CancelTxPopup 等）— iOS 暂无

### P6-2 签名历史 & 活动
- [x] SignedTextHistoryView（签名文本历史 UI）— `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`
- [x] SignHistoryManager（签名历史存储）— `mobile/ios/RabbyMobile/Core/SignHistoryManager.swift`
- [x] ActivitiesView（活动记录页）— `mobile/ios/RabbyMobile/Views/Activities/ActivitiesView.swift`
- [ ] DAppBrowser/WC 写入签名历史闭环 — 依赖 Phase 4（personal_sign / typedData）

### P6-3 Token 授权管理
- [x] TokenApprovalView（入口 + 列表骨架）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（⚠️ 未完整对接 OpenAPI/撤销）
- [ ] 授权详情 + 撤销闭环 — iOS 暂无（需对接 OpenAPI revoke & Approval Tx 构建）

### P6-4 NFT 授权管理
- [x] NFTApprovalView（基础列表）— `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`
- [ ] 按合约分组/撤销授权/搜索 — iOS 暂无（扩展端能力）

**Phase 6 产出**: 用户可查看交易/签名历史，管理 Token/NFT 授权（⚠️ TokenApproval revoke 闭环待补）

---

## 阶段七：NFT + 资产浏览 (Phase 7)

> 参考代码量: NFTView ~504 行

### P7-1 NFT 浏览
- [x] NFTView 主页（合集/详情/发送入口）— `mobile/ios/RabbyMobile/Views/NFT/NFTView.swift`
- [x] 资产页内 NFT Gallery（列表/搜索/详情）— `mobile/ios/RabbyMobile/Views/Assets/NFTGalleryView.swift` + `mobile/ios/RabbyMobile/Views/Assets/NFTDetailView.swift`
- [x] NFTManager（数据加载/发送入口）— `mobile/ios/RabbyMobile/Core/NFTManager.swift`（⚠️ ERC1155 calldata 仍需补齐，见 Phase 3）
- [ ] 空状态插图/骨架屏资源（体验对齐）— 见 0.4（可选）

**Phase 7 产出**: 用户可浏览 NFT 合集

---

## 阶段八：设置 + 地址管理 (Phase 8)

> 参考代码量: ManageAddress ~1,052 行, AddressDetail ~1,175 行, Settings ~1,605 行

### P8-1 设置面板
- [x] SettingsView（设置入口 + 主配置项）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] LockWallet（锁定钱包）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift` + `mobile/ios/RabbyMobile/Core/AutoLockManager.swift`
- [x] AutoLock（自动锁定时间）— `mobile/ios/RabbyMobile/Core/AutoLockManager.swift` + `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] SwitchLang / ThemeMode / Currency（语言/主题/货币）— `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` + `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（⚠️ i18n JSON 资源缺失见 0.4）
- [x] Face ID / Touch ID 开关 — `mobile/ios/RabbyMobile/Core/BiometricAuthManager.swift` + `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [ ] ClearPending（清除 pending/重置账户）— iOS 暂无（可基于 `mobile/ios/RabbyMobile/Core/TransactionManager.swift` 补齐）
- [ ] PwdForNonWhitelisted / DappAccount mode（扩展特性）— iOS 暂未对齐
- [x] Version（版本信息展示）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`（当前写死 0.93.77）
- [ ] FollowUs（社交媒体链接）— iOS 暂无

### P8-2 地址管理
- [x] AddressManagementView（地址列表/切换/移除）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] AddressDetailView（地址详情/别名/移除/备份入口）— `mobile/ios/RabbyMobile/Views/AddressDetail/AddressDetailView.swift`
- [x] AddressBackupView（助记词/私钥备份）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] 删除确认弹窗（Remove Address）— `mobile/ios/RabbyMobile/Views/AddressDetail/AddressDetailView.swift`
- [ ] SeedPhraseDelete（删除种子/删除全部地址）— iOS 暂无（当前仅支持移除单地址）
- [x] GnosisQueueView（多签队列页）— `mobile/ios/RabbyMobile/Views/Settings/GnosisQueueView.swift`（⚠️ 数据闭环待核实）

### P8-3 链管理
- [x] ChainListView（链列表）— `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`
- [x] CustomRPCView（自定义 RPC 配置页）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] CustomRPCManager（自定义 RPC 数据）— `mobile/ios/RabbyMobile/Core/CustomRPCManager.swift`
- [x] CustomTestnetView（自定义测试网配置页）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [x] CustomTestnetManager（测试网数据）— `mobile/ios/RabbyMobile/Core/CustomTestnetManager.swift`
- [x] SyncChainManager（链数据同步）— `mobile/ios/RabbyMobile/Core/SyncChainManager.swift`
- [x] AdvancedSettingsView（高级设置页）— `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`

**Phase 8 产出**: 完整的设置中心 + 地址管理 + 链/RPC 配置

---

## 阶段九：GasAccount + Perps (Phase 9)

> 参考代码量: GasAccount ~3,712 行, Perps ~13,148 行

### P9-1 Gas 代付
- [x] GasAccountView（入口 + 列表骨架）— `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（⚠️ 多数交互为占位）
- [x] GasAccountManager（数据/接口封装）— `mobile/ios/RabbyMobile/Core/GasAccountManager.swift`
- [ ] 登录签名流程（LoginCard/SignIn）— iOS 暂无（需对齐扩展“Gas 登录”能力）
- [ ] Deposit/Withdraw 闭环（充值/提现）— iOS 暂无（当前 deposit 为占位）
- [ ] Gas 使用历史对接（真实数据 + 分页）— iOS 暂未对齐
- [ ] 相机扫码（WalletConnect URI/地址/充值二维码）— iOS 暂无（见 0.3 与 Phase 12）

### P9-2 Perps 合约交易
- [x] PerpsView（UI 骨架：Trade/Positions/Orders）— `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（PerpsView）
- [x] PerpsManager（本地 store + 下单骨架）— `mobile/ios/RabbyMobile/Core/PerpsManager.swift`（⚠️ API/仓位/订单均为 TODO）
- [ ] 对接 Perps API（positions/orders/markets/agent wallet）— `mobile/ios/RabbyMobile/Core/PerpsManager.swift`
- [ ] 风险等级/弹窗体系/邀请/新手流程等（扩展端 13+ 弹窗）— iOS 暂未实现

**Phase 9 产出**: Gas 代付 + 合约交易功能完成

---

## 阶段十：硬件钱包 + WalletConnect (Phase 10)

> 参考代码量: HDManager ~3,206 行

### P10-1 硬件钱包连接
- [x] LedgerConnectView（连接入口 UI）— `mobile/ios/RabbyMobile/Views/HardwareWallet/LedgerConnectView.swift`
- [x] BluetoothManager（BLE 管理）— `mobile/ios/RabbyMobile/Core/HardwareWallet/BluetoothManager.swift`
- [x] LedgerKeyring（Ledger Keyring 骨架）— `mobile/ios/RabbyMobile/Core/HardwareWallet/LedgerKeyring.swift`
- [ ] Keystone/OneKey/Trezor/ImKey 等（扩展端全套硬件）— iOS 暂未实现
- [ ] QRCodeReader（扫码组件）— iOS 暂无（Phase 12：AVFoundation）

### P10-2 HD Manager
- [x] 账户切换/链切换 Sheet（部分对标）— `mobile/ios/RabbyMobile/Views/Import/HDManagerSwitchViews.swift`
- [ ] 硬件地址管理页（完整对标 HDManager）— iOS 暂无

### P10-3 硬件签名等待
- [ ] 硬件签名等待/交互（Ledger/QR/WatchOnly）— iOS 暂无（需与 Phase 4 Approval 体系打通）

### P10-4 WalletConnect
- [x] WalletConnectView（连接页 UI）— `mobile/ios/RabbyMobile/Views/More/GasAccountView.swift`（WalletConnectView）
- [x] DeepLink 接入（wc: / rabbywallet://wc?uri=...）— `mobile/ios/RabbyMobile/RabbyMobileApp.swift`
- [ ] WalletConnect v2 pairing/connect/sign/tx — `mobile/ios/RabbyMobile/Core/WalletConnectManager.swift`（pair/connect notImplemented）

### P10-5 多签钱包
- [x] WatchGnosisSessionKeyrings（Gnosis/Watch keyring 骨架）— `mobile/ios/RabbyMobile/Core/WatchGnosisSessionKeyrings.swift`
- [x] GnosisQueueView（队列页骨架）— `mobile/ios/RabbyMobile/Views/Settings/GnosisQueueView.swift`
- [ ] ImportGnosisAddress / Cobo / Coinbase 等导入流程 — iOS 暂未实现（需按产品规划补）

**Phase 10 产出**: 所有硬件钱包支持 + WalletConnect + 多签

---

## 阶段十一：Ecology + Points + Dapp (Phase 11)

> 参考代码量: Ecology ~2,850 行, RabbyPoints ~1,737 行

### P11-1 Ecology 链上生态
- [ ] Ecology 活动入口/专题页（DBK/Sonic 等）— iOS 暂未对齐（可先用 DAppBrowser 打开对应站点）

### P11-2 Rabby Points 积分
- [x] RabbyPointsManager（积分接口/本地存储）— `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`
- [x] RabbyPointsView（积分页：总分/排名/邀请链接/每日领取/历史）— `mobile/ios/RabbyMobile/Views/More/MiscViews.swift`
- [ ] TopBoard/更复杂的 Claim Item/验证地址等（扩展端完整形态）— iOS 暂未对齐（按产品需要补）

### P11-3 Dapp 搜索
- [x] DAppBrowserView（URL 输入 + Popular DApps + WKWebView provider 注入）— `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`
- [x] provider 注入与 eth_sendTransaction 请求转 Approval — `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`
- [ ] personal_sign / typedData 请求支持 — 见 Phase 4（`handleSignMessage` 未实现）
- [ ] Bookmarks 列表/持久化 — iOS 暂未实现（当前仅内存数组）

### P11-4 其他
- [x] ConnectedSitesView（已连接站点）— `mobile/ios/RabbyMobile/Views/Settings/SettingsView.swift`
- [ ] MetaMaskModeDapps/PreferMetamaskDapps（扩展特性）— iOS 暂未对齐（可选）
- [ ] ImportMetaMask / RequestPermission / QRCodeCheckerDetail / 测试网水龙头 等（扩展额外页）— iOS 暂未实现（按产品需要补）

**Phase 11 产出**: 生态入口 + 积分系统 + Dapp 搜索/管理

---

## 阶段十二：iOS 平台独有适配 (Phase 12)

> 扩展没有但 iOS 必须的功能

### P12-1 安全 & 身份
- [x] Face ID / Touch ID 生物识别集成 — `mobile/ios/RabbyMobile/Core/BiometricAuthManager.swift`
- [x] iOS Keychain 安全存储 — `mobile/ios/RabbyMobile/Core/StorageManager.swift`
- [x] AutoLock（切后台/超时自动锁定）— `mobile/ios/RabbyMobile/Core/AutoLockManager.swift` + `mobile/ios/RabbyMobile/RabbyMobileApp.swift`
- [ ] 切后台自动模糊（隐私遮罩）— iOS 暂无（可加 Window overlay/blur）

### P12-2 通知 & 链接
- [x] APNs 权限请求 + 注册（基础）— `mobile/ios/RabbyMobile/RabbyMobileApp.swift`
- [x] 本地通知能力（基础）— `mobile/ios/RabbyMobile/Core/NotificationManager.swift`
- [ ] 交易确认/完成/失败“后端推送”闭环 — iOS 暂未实现（需服务端支持）
- [x] Deep Link（wc: / rabbywallet://wc?uri=...）— `mobile/ios/RabbyMobile/RabbyMobileApp.swift`（⚠️ WC pairing 未完成）
- [ ] Universal Links（rabby.io → App）— iOS 暂无（需 Associated Domains）

### P12-3 硬件适配
- [x] 蓝牙 BLE（Ledger 连接骨架）— `mobile/ios/RabbyMobile/Core/HardwareWallet/BluetoothManager.swift`
- [ ] 相机扫码（AVFoundation）— iOS 暂无（当前仅二维码生成）

### P12-4 用户体验
- [x] 手势导航（系统默认 + WebView 手势）— iOS 原生（WKWebView 已开启 `allowsBackForwardNavigationGestures`）
- [ ] Haptic Feedback（触觉反馈）— iOS 暂无
- [ ] Widget（余额/资产 WidgetKit）— iOS 暂无
- [ ] App Clips — iOS 暂无

### P12-5 DApp Browser (iOS 独有)
- [x] App 内浏览器（WKWebView）— `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`
- [x] window.ethereum 注入（JS Bridge）— `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppBrowserView.swift`
- [ ] DApp 权限管理闭环（连接授权弹窗/断开/多账户/多链）— ⚠️ 部分能力在 `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`（`DAppPermissionManager`）
- [ ] URL 白名单/黑名单（钓鱼网站拦截）— iOS 暂无（可复用扩展端规则/黑名单源）

**Phase 12 产出**: iOS 平台全部适配完成

---

## 阶段十三：Lending + 剩余服务 (Phase 13)

> 补全所有剩余后台服务（以 iOS `Core/*Manager.swift` 为准；扩展端 React Hooks 不做 1:1 迁移）

### P13-1 Lending 借贷
- [x] LendingManager（协议/仓位数据拉取）— `mobile/ios/RabbyMobile/Core/LendingManager.swift`
- [x] LendingView（展示 UI）— `mobile/ios/RabbyMobile/Views/More/LendingPerpsAdvancedView.swift`（LendingView）
- [ ] 借贷操作闭环（Supply/Borrow/Repay/Withdraw）— iOS 暂无（需补 Approval Action 解析 + Tx 构建）

### P13-2 其余服务补齐（iOS）
- [x] Session/偏好/本地存储 — `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` + `mobile/ios/RabbyMobile/Core/StorageManager.swift`
- [x] 链同步/离线链数据（基础）— `mobile/ios/RabbyMobile/Core/SyncChainManager.swift`
- [x] Permission（Connected Sites 存储）— `mobile/ios/RabbyMobile/Core/StorageManager.swift` + `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift`
- [x] Notification（本地通知 + APNs 注册）— `mobile/ios/RabbyMobile/Core/NotificationManager.swift` + `mobile/ios/RabbyMobile/RabbyMobileApp.swift`
- [ ] UserGuide UI 接入（overlay 引导）— `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`（UserGuideManager）
- [ ] MetaMaskMode/InnerDappFrame 等扩展特有服务 — 见第 27 章（可选/N/A）
- [ ] WidgetKit / Push backend / QR Scanner 等 iOS 平台补齐 — 见 Phase 12

### P13-3 扩展端 Hooks（React）迁移
- [ ] N/A（iOS 无 React Hooks；以 SwiftUI + ObservableObject 为主）

**Phase 13 产出**: Lending（展示）+ iOS 端剩余服务补齐

---

## 阶段十三·五：Desktop 桌面端功能迁移 (Phase 13.5) — ⚡可选 ⭐验证补充

> **注意**: 以下为桌面端专用功能，共 ~63,000+ 行代码。可根据产品规划选择性迁移。

### P13.5-1 Lending 借贷功能 (优先级较高)
- [ ] **DesktopLending 主页** — `src/ui/views/DesktopLending/index.tsx` (~77 文件)
- [ ] **MarketSelector** 市场选择器 (Aave V3/Compound等) — `DesktopLending/components/MarketSelector/`
- [ ] **LendingRow** 供应/借贷行项 — `DesktopLending/components/LendingRow/`
- [ ] **SummaryBar** 摘要栏 (健康因子/净值) — `DesktopLending/components/SummaryBar/`
- [ ] **SupplyModal** 存入弹窗 — `DesktopLending/components/SupplyModal/`
- [ ] **BorrowModal** 借款弹窗 — `DesktopLending/components/BorrowModal/`
- [ ] **RepayModal** 还款弹窗 — `DesktopLending/components/RepayModal/`
- [ ] **WithdrawModal** 提取弹窗 — `DesktopLending/components/WithdrawModal/`
- [ ] **ManageEmodeModal** E-Mode 管理 — `DesktopLending/components/ManageEmodeModal/`
- [ ] **HealthFactor** 健康因子组件 — `DesktopLending/components/HFDescription/`
- [ ] **Lending Hooks** — pool / market / useMode / LendingDataContext / useLendingService

### P13.5-2 Desktop Perps 专业合约 (优先级中)
- [ ] **DesktopPerps 主页** — `src/ui/views/DesktopPerps/index.tsx` (~70+ 文件)
- [ ] **TradingPanel** 交易面板 (Market/Limit/TWAP/Scale) — `DesktopPerps/components/TradingPanel/`
- [ ] **ChartArea** K线图区域 — `DesktopPerps/components/ChartArea/`
- [ ] **OrderBookTrades** 订单簿+成交记录 — `DesktopPerps/components/OrderBookTrades/`
- [ ] **UserInfoHistory** 持仓/订单/历史/资金费率 — `DesktopPerps/components/UserInfoHistory/`
- [ ] **DesktopPerps Modals** (ClosePosition/EditTpSL/EditMargin) — `DesktopPerps/modal/`
- [ ] **DesktopPerps Hooks** — usePerpsTradingState / usePerpsProState / usePerpsProInit / usePerpsProPosition

### P13.5-3 Desktop Profile 个人中心 (优先级中)
- [ ] **DesktopProfile 主页** — `src/ui/views/DesktopProfile/index.tsx` (~30+ 文件)
- [ ] **TransactionsTabPane** 交易记录标签页 — `DesktopProfile/components/TransactionsTabPane/`
- [ ] **NFTTabPane** NFT标签页(Listing/Offer/Trading) — `DesktopProfile/components/NFTTabPane/`
- [ ] **SendTokenModal** 发送代币弹窗 — `DesktopProfile/components/SendTokenModal/`
- [ ] **SendNftModal** 发送NFT弹窗 — `DesktopProfile/components/SendNftModal/`
- [ ] **SignatureRecordModal** 签名记录弹窗 — `DesktopProfile/components/SignatureRecordModal/`
- [ ] **GnosisQueueModal** Gnosis队列弹窗 — `DesktopProfile/components/GnosisQueueModal/`

**Phase 13.5 产出**: 借贷 + 专业合约交易 + 桌面端个人中心功能

---

## 阶段十四：测试 + 上线 (Phase 14)

### P14-1 测试
- [ ] 单元测试 — 核心服务 (Keyring / Swap / Bridge / SecurityEngine)
- [ ] 组件测试 — 关键 UI 组件
- [ ] E2E 测试 — 主要用户流程 (创建钱包 → 发送代币 → Swap)
- [ ] 安全审计 — 密钥管理 / 签名流程 / 存储安全
- [ ] 性能测试 — 大量代币/NFT 列表渲染 / 多链余额加载

### P14-2 上线准备
- [ ] App Store 审核材料准备 (截图/描述/隐私政策)
- [ ] TestFlight 内测
- [ ] App Store 提审
- [ ] 灰度发布 + 监控

---

## 开发优先级总览

```
Phase 0  [基建]  ████████████████████ → 项目可运行 (含补充的8个基础组件)
Phase 1  [账户]  ████████████████ → 可创建/导入钱包
Phase 2  [主页]  ████████████████████████ → 可查看资产 (含CommonPopup ~10,438行)
Phase 3  [收发]  ████████████████ → 可发送/接收
Phase 4  [签名]  ████████████████████████ → 交易签名引擎 (最大)
Phase 5  [DeFi]  ████████████████ → Swap + Bridge
Phase 6  [历史]  ████████████ → 交易历史 + 授权管理
Phase 7  [NFT]   ██████ → NFT 浏览
Phase 8  [设置]  ████████████ → 设置 + 地址管理
Phase 9  [Gas]   ████████████████ → GasAccount + Perps
Phase 10 [硬件]  ████████████████ → 硬件钱包 + WalletConnect
Phase 11 [生态]  ████████████████ → Ecology + Points + Dapp (含5个补充视图)
Phase 12 [iOS]   ████████████ → iOS 平台适配
Phase 13 [补全]  ██████████████ → 剩余服务 (含3个补充服务 + 7个补充Hooks)
Phase 13.5[桌面] ████████████████████████ → Desktop借贷/专业合约/个人中心 (⚡可选)
Phase 14 [上线]  ████████ → 测试 + 发布
```

### MVP 最小可用产品 (Phase 0-3)
完成后用户可以：创建钱包 → 查看资产 → 发送/接收代币

### 核心功能版 (Phase 0-6)
完成后用户可以：以上 + Swap兑换 + 跨链桥 + 交易历史 + 授权管理

### 完整版 (Phase 0-14)
与扩展钱包功能一比一对齐

### 旗舰版 (Phase 0-14 + Phase 13.5)
包含 Desktop 桌面端借贷/专业合约/个人中心功能
