# Rabby 原项目功能全面清单

基于 `src/ui/views/MainRoute.tsx`、`src/ui/views/index.tsx`、`src/ui/models` 整理。

## 一、入口与认证

| 路径 | 组件 | 功能 |
|------|------|------|
| `/` | SortHat | 根据 UI 类型跳转 |
| `/unlock` | Unlock | 解锁钱包 |
| `/forgot-password` | ForgotPassword | 忘记密码 |
| `/dashboard` | Dashboard | 主仪表盘 |

## 二、新用户引导

| 路径 | 组件 | 功能 |
|------|------|------|
| `/welcome` | Welcome | 欢迎页 |
| `/new-user/guide` | Guide | 新手引导 |
| `/new-user/import-list` | ImportWalletList | 导入方式选择 |
| `/new-user/import/private-key` | NewUserImportPrivateKey | 导入私钥 |
| `/new-user/import/seed-phrase` | ImportSeedPhrase | 导入助记词 |
| `/new-user/import/gnosis-address` | NewUserImportGnosisAddress | 导入 Gnosis 地址 |
| `/new-user/import/hardware/:type` | NewUserImportHardware | 导入硬件钱包 |
| `/new-user/import/hardware/ledger` | NewUserImportLedger | Ledger |
| `/new-user/import/hardware/imkey` | NewUserImportImKey | ImKey |
| `/new-user/import/hardware/keystone` | NewUserImportKeystone | Keystone |
| `/new-user/import/hardware/onekey` | NewUserImportOneKey | OneKey |
| `/new-user/import/:type/set-password` | NewUserSetPassword | 设置密码 |
| `/new-user/create-seed-phrase` | CreateSeedPhrase | 创建助记词 |
| `/new-user/backup-seed-phrase` | BackupSeedPhrase | 备份助记词 |
| `/new-user/success` | ImportOrCreatedSuccess | 导入/创建成功 |
| `/new-user/ready` | ReadyToUse | 准备就绪 |
| `/new-user/import/select-address` | NewUserSelectAddress | 选择地址 |

## 三、钱包导入（已有账户）

| 路径 | 组件 | 功能 |
|------|------|------|
| `/password` | CreatePassword | 创建密码 |
| `/no-address` | NoAddress | 无地址提示 |
| `/import` | ImportMode | 导入模式选择 |
| `/import/key` | ImportPrivateKey | 导入私钥 |
| `/import/json` | ImportJson | 导入 JSON |
| `/import/mnemonics` | InputMnemonics | 导入助记词 |
| `/import/select-address` | SelectAddress | 选择地址 |
| `/import/hardware` | ImportHardware | 硬件钱包入口 |
| `/import/hardware/ledger-connect` | ConnectLedger | Ledger 连接 |
| `/import/hardware/trezor-connect` | ConnectTrezor | Trezor 连接 |
| `/import/hardware/onekey` | ConnectOneKey | OneKey 连接 |
| `/import/hardware/imkey-connect` | ImKeyConnect | ImKey 连接 |
| `/import/hardware/keystone` | KeystoneConnect | Keystone 连接 |
| `/import/hardware/qrcode` | QRCodeConnect | 二维码硬件 |
| `/import/watch-address` | ImportWatchAddress |  watch 地址 |
| `/import/wallet-connect` | WalletConnectTemplate | WalletConnect |
| `/import/success` | ImportSuccess | 导入成功 |
| `/import/add-from-current-seed-phrase` | AddFromCurrentSeedPhrase | 从当前助记词追加 |
| `/import/gnosis` | ImportGnosis | Gnosis Safe |
| `/import/cobo-argus` | ImportCoboArgus | Cobo Argus |
| `/import/coinbase` | ImportCoinbase | Coinbase |
| `/import/metamask` | ImportMyMetaMaskAccount | 导入 MetaMask |

## 四、资产与交易

| 路径 | 组件 | 功能 |
|------|------|------|
| `/activities` | Activities | 活动列表 |
| `/history` | HistoryPage | 交易历史 |
| `/history/filter-scam` | HistoryPage | 过滤诈骗 |
| `/gnosis-queue` | GnosisQueue | Gnosis 交易队列 |
| `/send-token` | SendToken | 发送代币 |
| `/send-nft` | SendNFT | 发送 NFT |
| `/receive` | Receive | 收款 |
| `/select-to-address` | SelectToAddress | 选择收款地址 |
| `/dex-swap` | Swap | 代币兑换 |

## 五、高级功能

| 路径 | 组件 | 功能 |
|------|------|------|
| `/bridge` | Bridge | 跨链桥 |
| `/gas-account` | GasAccount | Gas 账户 |
| `/rabby-points` | RabbyPoints | Rabby 积分 |
| `/perps` | Perps | 永续合约首页 |
| `/perps/single-coin/:coin` | PerpsSingleCoin | 单币种永续 |
| `/perps/explore` | ExploreMore | 探索更多 |
| `/perps/history/:coin` | PerpsHistoryPage | 永续历史 |
| `/ecology/:chainId` | Ecology | 链生态 |
| `/nft` | NFTView | NFT 视图 |
| `/dapp-search` | DappSearchPage | Dapp 搜索 |

## 六、Dapp 与权限

| 路径 | 组件 | 功能 |
|------|------|------|
| `/approval` | Approval | 统一审批（交易/签名） |
| `/token-approval` | TokenApproval | Token 授权审批 |
| `/nft-approval` | NFTApproval | NFT 审批 |
| `/request-permission` | RequestPermission | 权限请求 |
| `/connect-approval` | ConnectApproval | 连接审批 |

## 七、设置与账户管理

| 路径 | 组件 | 功能 |
|------|------|------|
| `/switch-address` | AddressManagement | 地址管理/切换 |
| `/add-address` | AddAddress | 添加地址 |
| `/settings/address` | ManageAddress | 地址管理详情 |
| `/settings/address-detail` | AddressDetail | 地址详情 |
| `/settings/address-backup/private-key` | AddressBackupPrivateKey | 备份私钥 |
| `/settings/address-backup/mneonics` | AddressBackupMnemonics | 备份助记词 |
| `/settings/sites` | ConnectedSites | 已连接站点 |
| `/settings/chain-list` | ChainList | 链列表 |
| `/settings/switch-lang` | SwitchLang | 语言切换 |
| `/settings/advanced` | AdvancedSettings | 高级设置 |
| `/custom-rpc` | CustomRPC | 自定义 RPC |
| `/custom-testnet` | CustomTestnet | 自定义测试网 |
| `/whitelist-input` | WhitelistInput | 白名单输入 |
| `/metamask-mode-dapps` | MetamaskModeDappsGuide | MetaMask 模式指引 |
| `/metamask-mode-dapps/list` | MetamaskModeDappsList | MetaMask 模式 Dapp 列表 |

## 八、Models（后台数据/状态）

| Model | 职责 |
|-------|------|
| account | 当前账户 |
| accountToDisplay | 账户展示列表 |
| addressManagement | 地址管理 |
| app | 应用初始化 |
| appVersion | 版本与更新 |
| chains | 链列表 |
| contactBook | 通讯录 |
| createMnemonics | 创建助记词 |
| customRPC | 自定义 RPC |
| directSubmitTx | 直接提交交易 |
| exchange | 兑换 |
| gasAccount | Gas 账户 |
| gift | 礼物/空投 |
| importMnemonics | 导入助记词 |
| newUserGuide | 新手引导 |
| openapi | OpenAPI 调用 |
| permission | 站点权限 |
| perps | 永续合约 |
| preference | 偏好设置 |
| securityEngine | 安全引擎 |
| sign | 签名 |
| signTextHistory | 签名文本历史 |
| signTxHistory | 签名交易历史 |
| swap | Swap |
| transactions | 交易 |
| whitelist | 白名单 |

## 九、Web 迁移差异说明

| 能力 | 扩展 | Web |
|------|------|-----|
| 账户/私钥 | 本地加密存储 | 需 WalletConnect / 托管 |
| Dapp 注入 | window.ethereum | WalletConnect 连接 |
| 硬件钱包 | WebUSB/HID | 需移动端或扩展桥接 |
| 审批页 | 弹窗拦截 | 无原生拦截，需 WalletConnect 会话 |
| 存储 | Chrome Storage | 服务端 + localStorage |

Web 端可迁移：Dashboard、资产展示、Swap、Bridge、历史、设置、Dapp 搜索等展示型功能。  
签名、硬件钱包、Dapp 连接需通过 WalletConnect 或扩展桥接实现。

---

## 十、Web 前端迁移进度（apps/web）

| 路径 | 状态 | 说明 |
|------|------|------|
| `/` | ✅ | Dashboard 资产概览 |
| `/settings/*` | ✅ | 地址管理、链列表、高级设置 |
| `/send-token` | 占位 | 待实现 |
| `/dex-swap` | 占位 | 待实现 |
| `/bridge` | 占位 | 待实现 |
| `/history` | 占位 | 待实现 |
| `/receive` | 占位 | 待实现 |
| `/import` | 占位 | 待实现 |
| `/welcome` | ✅ | 欢迎页 |
| 其他 | 占位 | 见 ROUTES 映射 |
