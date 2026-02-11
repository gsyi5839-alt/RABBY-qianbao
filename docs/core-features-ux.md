# Rabby 核心功能与 UI/UX 说明

本文基于当前仓库的 `src/ui/views` 与 `src/background/service` 梳理核心功能与对应的 UI/UX 触点，便于后续前端与管理系统规划。

## 产品形态与入口
- UI 形态：浏览器弹窗（popup）、通知页（notification）、新标签页（tab）、桌面模式（desktop）。入口路由由 `SortHat` 决定。
- 体验要点：自动锁定/解锁、忘记密码流程、桌面模式下保留多模块常驻视图（Profile/Perps/Lending/Dapp Iframe）。

## 账户与钱包管理
- 创建与导入：助记词/私钥/JSON/观察地址、从当前助记词追加地址、导入 MetaMask 账户。
- 多钱包类型：硬件钱包（Ledger/Trezor/OneKey/Keystone/ImKey/BitBox02/Lattice）、Coinbase、Gnosis Safe、多签/托管（Cobo Argus）。
- 账号管理：地址列表、别名、备份助记词/私钥、选择发送地址、收款地址展示。
- UX：导入/创建引导分步、成功页确认、硬件设备连接等待与指引。

## 网络与链管理
- 链列表与切换、添加新链、Switch Chain 交互。
- 自定义 RPC、自定义测试网、测试网水龙头申请入口。
- UX：在签名/授权时提示链切换与新增链的明确确认步骤。

## 资产与交易
- 资产概览与活动：Dashboard、Activities、History/TransactionHistory。
- 代币与 NFT：资产详情、NFT 视图、发送/接收、NFT 发送。
- 批量/历史：签名文本历史、Gnosis 交易队列（GnosisQueue）。
- UX：余额变化/手续费/风险提示集中在审批页展示。

## Dapp 连接与权限
- 连接授权：RequestPermission、ConnectedSites、Dapp 搜索（DappSearch）。
- 模式兼容：MetaMask 模式/偏好列表（MetamaskModeDapps/PreferMetamaskDapps）。
- WalletConnect 连接流程。
- UX：连接请求与账户选择在 Approval 流程内完成，强调来源信息与权限范围。

## 交易/签名与安全
- 审批入口统一在 Approval：交易签名、Typed Data、个人签名、解密、获取公钥。
- 交易动作解析：转账、Swap、跨链、授权/撤销授权、添加流动性、Wrap/Unwrap、合约调用等。
- 安全引擎：风险等级标签、规则详情抽屉、异常提示。
- UX：Gas 设置、加速/取消、签名硬件等待、批量签名与迷你审批弹窗。

## 高级功能模块
- Swap、Bridge、Gas Account、Rabby Points。
- Perps（含 Desktop Perps）与 Lending（Desktop Lending）。
- Ecology/生态入口与桌面 Dapp Iframe。
- UX：提供独立入口页与桌面模式常驻视图，避免弹窗局促。

## 设置与偏好
- 高级设置（AdvanceSettings）、语言切换（SwitchLang）、白名单输入（WhitelistInput）。
- 自动锁定、主题模式、Dapp 账户开关等偏好设置与事件上报。

## UI/UX 关键流程（简版）
1) 新用户上手：Welcome → 新手引导 → 创建/导入 → 备份 → Ready to Use  
2) Dapp 连接：RequestPermission → 选择账户 → 安全提示 → 授权完成  
3) 交易签名：Approval → 交易解码/风险提示 → Gas 设置 → 确认/拒绝  
4) 资产操作：Dashboard/NFTView → 发送/接收 → 历史追踪
