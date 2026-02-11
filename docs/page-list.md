# 页面级清单（UI/UX）

本文基于路由与视图目录梳理页面清单，覆盖主要功能与交互触点。
来源：`src/ui/views/index.tsx`、`src/ui/views/MainRoute.tsx`、`src/ui/views/DesktopRoute.tsx`、`src/ui/views/Ecology/*/Entry.tsx`。

## 入口与全局
- `/`（SortHat）：启动分发器，判断登录/锁定/引导状态后跳转。UX：启动即刻反馈、避免空白。
- `/unlock`（Unlock）：解锁钱包。UX：自动锁定回跳、快捷键锁定。
- `/forgot-password`（ForgotPassword）：找回/重置流程入口。
- `/dashboard`（Dashboard）：资产与概览入口页。
- 全局弹层：`CommonPopup`/`PortalHost`/`GlobalSignerPortal`/`GlobalTypedDataSignerPortal`（全局审批与弹窗层）。

## 新用户引导（/new-user/*）
- `/new-user/guide`（Guide）：新手引导。
- `/new-user/import-list`（ImportWalletList）：导入方式选择。
- `/new-user/import/private-key`（NewUserImportPrivateKey）
- `/new-user/import/gnosis-address`（NewUserImportGnosisAddress）
- `/new-user/import/seed-phrase`（ImportSeedPhrase）
- `/new-user/import/hardware/:type`（NewUserImportHardware）
- `/new-user/import/hardware/ledger|imkey|keystone|onekey`（对应硬件流程）
- `/new-user/import/:type/set-password`（NewUserSetPassword）
- `/new-user/create-seed-phrase`（CreateSeedPhrase）
- `/new-user/backup-seed-phrase`（BackupSeedPhrase）
- `/new-user/success`（ImportOrCreatedSuccess）
- `/new-user/ready`（ReadyToUse）
- `/new-user/import/select-address`（NewUserSelectAddress）
UX 要点：分步流程、设备连接状态反馈、成功确认页明确下一步。

## 钱包创建/导入（非新手流程）
- `/password`（CreatePassword）
- `/mnemonics/create`（CreateMnemonics）
- `/import`（ImportMode）：导入方式入口。
- `/import/key`（ImportPrivateKey）
- `/import/json`（ImportJson）
- `/import/mnemonics`（InputMnemonics）
- `/import/select-address`（SelectAddress）
- `/import/hardware`（ImportHardware）
- `/import/hardware/ledger-connect`（ConnectLedger）
- `/import/hardware/trezor-connect`（ConnectTrezor）
- `/import/hardware/onekey`（ConnectOneKey）
- `/import/hardware/imkey-connect`（ImKeyConnect）
- `/import/hardware/keystone`（KeystoneConnect）
- `/import/hardware/qrcode`（QRCodeConnect）
- `/import/watch-address`（ImportWatchAddress）
- `/import/wallet-connect`（WalletConnectTemplate）
- `/import/gnosis`（ImportGnosis）
- `/import/cobo-argus`（ImportCoboArgus）
- `/import/coinbase`（ImportCoinbase）
- `/import/metamask`（ImportMyMetaMaskAccount）
- `/import/add-from-current-seed-phrase`（AddFromCurrentSeedPhrase）
- `/import/success` 与 `/popup/import/success`（ImportSuccess）
UX 要点：导入渠道一致的错误提示、硬件设备等待态、成功后的引导操作。

## 账户与地址管理
- `/add-address`（AddAddress）：新增地址。
- `/switch-address`（AddressManagement）：地址切换与管理。
- `/select-to-address`（SelectToAddress）：发送目标地址选择。
- `/settings/address`（ManageAddress）：地址管理入口。
- `/settings/address-detail`（AddressDetail）：地址详情。
- `/settings/address-backup/private-key`（AddressBackup/PrivateKey）
- `/settings/address-backup/mneonics`（AddressBackup/Mnemonics）
UX 要点：敏感信息遮罩、确认提示、批量管理与搜索。

## Dapp 连接与权限/审批
- `/request-permission`（RequestPermission）：站点授权入口。
- `/connect-approval`（ConnectApproval）：连接审批页。
- `/approval`（Approval）：交易/签名/授权统一审批页。
- `/token-approval`（TokenApproval）、`/nft-approval`（NFTApproval）
- `/settings/sites`（ConnectedSites）：已连接站点管理。
- `/dapp-search`（DappSearchPage）：Dapp 搜索入口。
- `/metamask-mode-dapps`（MetamaskModeDappsGuide）
- `/metamask-mode-dapps/list`（MetamaskModeDappsList）
- `/sync`（SyncToMobile，标注 todo remove）
UX 要点：来源站点信息、权限范围、风险提示、拒绝/确认明显区分。

## 资产与交易
- `/activities`（Activities）：活动/通知流。
- `/history`（HistoryPage）：交易历史。
- `/history/filter-scam`（HistoryPage，过滤疑似诈骗）
- `/send-token`（SendToken）
- `/send-nft`（SendNFT）
- `/receive`（Receive）
- `/nft`（NFTView）
- `/gnosis-queue`（GnosisQueue）
UX 要点：交易摘要/余额变化/手续费可视化，历史支持过滤与风险提示。

## 交易与资产高级功能
- `/dex-swap`（Swap）
- `/bridge`（Bridge）
- `/gas-account`（GasAccount）
- `/rabby-points`（RabbyPoints）
- `/perps`（Perps）
- `/perps/single-coin/:coin`（PerpsSingleCoin）
- `/perps/explore`（ExploreMore）
- `/perps/history/:coin`（PerpsHistoryPage）
- `/ecology/:chainId`（Ecology）  
  - `/:chainId/points`（Sonic Points）  
  - `/:chainId/mintNft`（Dbk Chain Mint）  
  - `/:chainId/bridge`（Dbk Chain Bridge）
UX 要点：复杂产品给独立入口与引导页，保持弹窗内信息密度可控。

## 网络与链
- `/settings/chain-list`（ChainList）
- `/custom-rpc`（CustomRPC）
- `/custom-testnet`（CustomTestnet）
UX 要点：链切换/新增链审批与风险提示明确。

## 设置与偏好
- `/settings/advanced`（AdvanceSettings）
- `/settings/switch-lang`（SwitchLang）
- `/whitelist-input`（WhitelistInput）
UX 要点：偏好变更即时生效且有可见反馈。

## 桌面模式（Desktop）
- `/desktop/profile`（DesktopProfile）：桌面模式个人/账户中心。
- `/desktop/perps`（DesktopPerpsEntry）
- `/desktop/lending`（DesktopLendingEntry）
- `/desktop/prediction`（DesktopInnerDapp）
UX 要点：常驻模块缓存，避免切换时丢失上下文。

## 其他内部/子页面（非顶级路由）
这些通常作为弹窗/子视图出现，不直接挂载为顶级路由：
- `SignedTextHistory`、`TransactionHistory`、`RequestDeBankTestnetGasToken`
- `PreferMetamaskDapps`、`HDManager`、`QRCodeCheckerDetail`
- `DesktopChainSelector`、`DesktopDappIframe`（桌面模式子模块）
